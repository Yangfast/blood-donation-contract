// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BloodDonationCreditSystem
 * @dev Optimized version with reduced contract size and fixed stack too deep
 */

contract BloodDonationCreditSystem {
    
    // ==================== State Variables ====================
    address public owner;
    
    // Compact storage: use smaller types where possible
    struct DonorInfo {
        address donorAddress;
        uint32 firstDonationDate;
        uint32 lastDonationDate;
        uint32 totalPoints;
        uint16 donationCount;
        string bloodType;
    }
    
    struct BloodUnit {
        uint64 bloodId;
        address donorAddress;
        uint32 donationTime;
        uint32 expiryDate;
        uint32 usedTime;
        uint16 bloodAmount;
        uint8 status; // Using uint8 for enum to save space
        address currentLocation;
        address usedByHospital;
        string donationType;
        string usagePurpose;
        bytes32 patientInfoHash;
    }
    
    struct BloodTransfer {
        uint32 timestamp;
        uint8 fromStatus;
        uint8 toStatus;
        address transferBy;
    }
    
    struct PointsConfig {
        uint16 basePoints;
        uint16 weight;
    }
    
    // 使用结构体封装返回数据，减少堆栈使用
    struct BloodInfo {
        uint64 id;
        address donor;
        string donationType;
        uint16 amount;
        uint8 status;
        uint32 donationTime;
        uint32 expiryDate;
        address location;
        address hospital;
        uint32 usedTime;
        string purpose;
        bytes32 patientHash;
    }
    
    // Storage mappings
    mapping(bytes32 => DonorInfo) private donors;
    mapping(address => uint64[]) private donorBloodIds;
    mapping(uint64 => BloodUnit) private bloodUnits;
    mapping(uint64 => BloodTransfer[]) private bloodTransfers;
    mapping(address => mapping(address => bool)) public queryAuthorizations;
    mapping(address => bool) public authorizedInstitutions;
    mapping(address => bool) public authorizedHospitals;
    mapping(bytes32 => PointsConfig) private pointsConfigs;
    
    uint64 private bloodIdCounter;
    
    // ==================== Events ====================
    event DonorRegistered(address donor, string bloodType, uint256 points, uint64 bloodId);
    event InstitutionUpdated(address institution, bool authorized);
    event HospitalUpdated(address hospital, bool authorized);
    event QueryAuthorized(address donor, address authorized);
    event CreditPointsMinted(address donor, uint256 points);
    event BloodStatusUpdated(uint64 bloodId, uint8 status, address updatedBy);
    event BloodTransferred(uint64 bloodId, address from, address to);
    event BloodUsed(uint64 bloodId, address hospital, string usagePurpose);
    
    // ==================== Constructor ====================
    constructor() {
        owner = msg.sender;
        bloodIdCounter = 1;
        
        // Initialize points config
        pointsConfigs[keccak256(abi.encode("whole_blood_200ml"))] = PointsConfig(100, 100);
        pointsConfigs[keccak256(abi.encode("whole_blood_400ml"))] = PointsConfig(200, 100);
        pointsConfigs[keccak256(abi.encode("component_blood"))] = PointsConfig(150, 120);
        pointsConfigs[keccak256(abi.encode("emergency_donation"))] = PointsConfig(200, 150);
        pointsConfigs[keccak256(abi.encode("rare_blood_type"))] = PointsConfig(180, 180);
        
        authorizedInstitutions[msg.sender] = true;
    }
    
    // ==================== Modifiers ====================
    modifier onlyOwner() {
        require(msg.sender == owner, "OW");
        _;
    }
    
    modifier onlyAuthorizedInstitution() {
        require(authorizedInstitutions[msg.sender], "NI");
        _;
    }
    
    modifier onlyAuthorizedHospital() {
        require(authorizedHospitals[msg.sender], "NH");
        _;
    }
    
    // ==================== Core Functions ====================
    
    function registerDonorAndBlood(
        address donorAddress,
        string calldata bloodType,
        string calldata donationType,
        uint16 bloodAmount
    ) external onlyAuthorizedInstitution {
        require(donorAddress != address(0), "IA");
        
        uint32 currentDate = uint32(block.timestamp);
        uint256 points = calculatePoints(donationType, bloodAmount);
        uint64 bloodId = bloodIdCounter++;
        
        bytes32 donorKey = keccak256(abi.encode(donorAddress));
        DonorInfo storage donor = donors[donorKey];
        
        // If first donation
        if (donor.donorAddress == address(0)) {
            donor.donorAddress = donorAddress;
            donor.firstDonationDate = currentDate;
            donor.lastDonationDate = currentDate;
            donor.totalPoints = uint32(points);
            donor.donationCount = 1;
            donor.bloodType = bloodType;
        } else {
            // Subsequent donation
            donor.lastDonationDate = currentDate;
            donor.totalPoints += uint32(points);
            donor.donationCount += 1;
            
            if (isAnnualContinuousDonation(donorAddress)) {
                uint16 bonusPoints = 50;
                donor.totalPoints += bonusPoints;
                points += bonusPoints;
            }
        }
        
        // Create blood record
        bloodUnits[bloodId] = BloodUnit({
            bloodId: bloodId,
            donorAddress: donorAddress,
            donationTime: currentDate,
            expiryDate: currentDate + 35 days,
            usedTime: 0,
            bloodAmount: bloodAmount,
            status: 0,
            currentLocation: msg.sender,
            usedByHospital: address(0),
            donationType: donationType,
            usagePurpose: "",
            patientInfoHash: 0
        });
        
        donorBloodIds[donorAddress].push(bloodId);
        
        // Record transfer
        bloodTransfers[bloodId].push(BloodTransfer({
            timestamp: currentDate,
            fromStatus: 0,
            toStatus: 0,
            transferBy: msg.sender
        }));
        
        emit DonorRegistered(donorAddress, bloodType, points, bloodId);
        emit CreditPointsMinted(donorAddress, points);
        emit BloodStatusUpdated(bloodId, 0, msg.sender);
    }
    
    function updateBloodStatus(
        uint64 bloodId,
        uint8 newStatus
    ) external {
        BloodUnit storage blood = bloodUnits[bloodId];
        require(blood.bloodId != 0, "BNE");
        require(blood.status != 6, "BU");
        require(blood.status != 7, "BE");
        
        // Check authorization
        require(
            authorizedInstitutions[msg.sender] || 
            authorizedHospitals[msg.sender] || 
            blood.currentLocation == msg.sender,
            "NA"
        );
        
        uint8 oldStatus = blood.status;
        require(isValidStatusTransition(oldStatus, newStatus), "IST");
        
        blood.status = newStatus;
        blood.currentLocation = msg.sender;
        
        if (newStatus == 4) {
            blood.currentLocation = address(0);
        }
        
        bloodTransfers[bloodId].push(BloodTransfer({
            timestamp: uint32(block.timestamp),
            fromStatus: oldStatus,
            toStatus: newStatus,
            transferBy: msg.sender
        }));
        
        emit BloodStatusUpdated(bloodId, newStatus, msg.sender);
    }
    
    function recordBloodUsage(
        uint64 bloodId,
        bytes32 patientInfoHash,
        string calldata usagePurpose
    ) external onlyAuthorizedHospital {
        BloodUnit storage blood = bloodUnits[bloodId];
        require(blood.bloodId != 0, "BNE");
        require(blood.status == 4, "BND");
        require(block.timestamp <= blood.expiryDate, "BE");
        
        blood.status = 6;
        blood.usedByHospital = msg.sender;
        blood.usedTime = uint32(block.timestamp);
        blood.patientInfoHash = patientInfoHash;
        blood.usagePurpose = usagePurpose;
        
        bloodTransfers[bloodId].push(BloodTransfer({
            timestamp: uint32(block.timestamp),
            fromStatus: 4,
            toStatus: 6,
            transferBy: msg.sender
        }));
        
        // Update donor points
        bytes32 donorKey = keccak256(abi.encode(blood.donorAddress));
        donors[donorKey].totalPoints += 50;
        
        emit BloodUsed(bloodId, msg.sender, usagePurpose);
        emit CreditPointsMinted(blood.donorAddress, 50);
    }
    
    // ==================== Query Functions ====================
    
    function getDonorInfo(address donorAddress) external view returns (
        address,
        string memory,
        uint32,
        uint32,
        uint32,
        uint16
    ) {
        require(
            msg.sender == donorAddress ||
            queryAuthorizations[donorAddress][msg.sender],
            "NAQ"
        );
        
        bytes32 donorKey = keccak256(abi.encode(donorAddress));
        DonorInfo memory donor = donors[donorKey];
        require(donor.donorAddress != address(0), "DNE");
        
        return (
            donor.donorAddress,
            donor.bloodType,
            donor.firstDonationDate,
            donor.lastDonationDate,
            donor.totalPoints,
            donor.donationCount
        );
    }
    
    // 修复：使用结构体封装返回数据，避免堆栈溢出
    function getBloodInfo(uint64 bloodId) external view returns (BloodInfo memory) {
        BloodUnit memory blood = bloodUnits[bloodId];
        require(blood.bloodId != 0, "BNE");
        
        // Check authorization - split into variables to avoid stack too deep
        address bloodDonor = blood.donorAddress;
        bool isDonor = msg.sender == bloodDonor;
        bool isAuthorized = queryAuthorizations[bloodDonor][msg.sender];
        bool isInstitution = authorizedInstitutions[msg.sender];
        bool isHospital = authorizedHospitals[msg.sender];
        
        require(isDonor || isAuthorized || isInstitution || isHospital, "NAB");
        
        return BloodInfo({
            id: blood.bloodId,
            donor: blood.donorAddress,
            donationType: blood.donationType,
            amount: blood.bloodAmount,
            status: blood.status,
            donationTime: blood.donationTime,
            expiryDate: blood.expiryDate,
            location: blood.currentLocation,
            hospital: blood.usedByHospital,
            usedTime: blood.usedTime,
            purpose: blood.usagePurpose,
            patientHash: blood.patientInfoHash
        });
    }
    
    function getBloodInfoBasic(uint64 bloodId) external view returns (
        uint8 status,
        uint32 expiryDate,
        address location,
        string memory donationType
    ) {
        BloodUnit memory blood = bloodUnits[bloodId];
        require(blood.bloodId != 0, "BNE");
        
        // Public info - no authorization required
        return (
            blood.status,
            blood.expiryDate,
            blood.currentLocation,
            blood.donationType
        );
    }
    
    // 新增：获取血液使用信息（用于前台显示）
    function getBloodUsageInfo(uint64 bloodId) external view returns (
        address hospital,
        uint32 usedTime,
        string memory purpose,
        bytes32 patientHash
    ) {
        BloodUnit memory blood = bloodUnits[bloodId];
        require(blood.bloodId != 0, "BNE");
        require(blood.status == 6, "BNU"); // Blood Not Used
        
        // Check authorization
        address bloodDonor = blood.donorAddress;
        bool isDonor = msg.sender == bloodDonor;
        bool isAuthorized = queryAuthorizations[bloodDonor][msg.sender];
        bool isHospital = authorizedHospitals[msg.sender];
        
        require(isDonor || isAuthorized || isHospital, "NAU");
        
        return (
            blood.usedByHospital,
            blood.usedTime,
            blood.usagePurpose,
            blood.patientInfoHash
        );
    }
    
    function getDonorBloodIds(address donorAddress) external view returns (uint64[] memory) {
        require(
            msg.sender == donorAddress ||
            queryAuthorizations[donorAddress][msg.sender] ||
            authorizedInstitutions[msg.sender],
            "NAD"
        );
        return donorBloodIds[donorAddress];
    }
    
    function getBloodTransfers(uint64 bloodId) external view returns (
        uint32[] memory timestamps,
        uint8[] memory fromStatuses,
        uint8[] memory toStatuses,
        address[] memory transferBys
    ) {
        BloodUnit memory blood = bloodUnits[bloodId];
        require(blood.bloodId != 0, "BNE");
        
        // Check authorization
        address bloodDonor = blood.donorAddress;
        bool isDonor = msg.sender == bloodDonor;
        bool isAuthorized = queryAuthorizations[bloodDonor][msg.sender];
        bool isInstitution = authorizedInstitutions[msg.sender];
        bool isHospital = authorizedHospitals[msg.sender];
        
        require(isDonor || isAuthorized || isInstitution || isHospital, "NAH");
        
        BloodTransfer[] memory transfers = bloodTransfers[bloodId];
        uint256 length = transfers.length;
        
        timestamps = new uint32[](length);
        fromStatuses = new uint8[](length);
        toStatuses = new uint8[](length);
        transferBys = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            timestamps[i] = transfers[i].timestamp;
            fromStatuses[i] = transfers[i].fromStatus;
            toStatuses[i] = transfers[i].toStatus;
            transferBys[i] = transfers[i].transferBy;
        }
    }
    
    function getTotalPoints(address donorAddress) external view returns (uint32) {
        require(
            msg.sender == donorAddress ||
            queryAuthorizations[donorAddress][msg.sender],
            "NAQ"
        );
        
        bytes32 donorKey = keccak256(abi.encode(donorAddress));
        DonorInfo memory donor = donors[donorKey];
        require(donor.donorAddress != address(0), "DNE");
        
        return donor.totalPoints;
    }
    
    function queryCreditLevel(address donorAddress) external view returns (uint32 points, uint8 level) {
        require(
            msg.sender == donorAddress ||
            queryAuthorizations[donorAddress][msg.sender],
            "NAQ"
        );
        
        bytes32 donorKey = keccak256(abi.encode(donorAddress));
        DonorInfo memory donor = donors[donorKey];
        require(donor.donorAddress != address(0), "DNE");
        
        points = donor.totalPoints;
        
        if (points >= 1000) {
            level = 3;
        } else if (points >= 800) {
            level = 2;
        } else if (points >= 500) {
            level = 1;
        } else {
            level = 0;
        }
    }
    
    // ==================== Management Functions ====================
    
    function authorizeInstitution(address institution) external onlyOwner {
        authorizedInstitutions[institution] = true;
        emit InstitutionUpdated(institution, true);
    }
    
    function revokeInstitution(address institution) external onlyOwner {
        authorizedInstitutions[institution] = false;
        emit InstitutionUpdated(institution, false);
    }
    
    function authorizeHospital(address hospital) external onlyOwner {
        authorizedHospitals[hospital] = true;
        emit HospitalUpdated(hospital, true);
    }
    
    function revokeHospital(address hospital) external onlyOwner {
        authorizedHospitals[hospital] = false;
        emit HospitalUpdated(hospital, false);
    }
    
    function authorizeQuery(address authorizedAddress) external {
        require(msg.sender != authorizedAddress, "CAY");
        queryAuthorizations[msg.sender][authorizedAddress] = true;
        emit QueryAuthorized(msg.sender, authorizedAddress);
    }
    
    function revokeQuery(address authorizedAddress) external {
        queryAuthorizations[msg.sender][authorizedAddress] = false;
        emit QueryAuthorized(msg.sender, authorizedAddress);
    }
    
    // ==================== Internal Helper Functions ====================
    
    function calculatePoints(string memory donationType, uint256 bloodAmount) 
        internal 
        view 
        returns (uint256) 
    {
        bytes32 configKey = keccak256(abi.encode(donationType));
        PointsConfig memory config = pointsConfigs[configKey];
        require(config.basePoints > 0, "IDT");
        require(bloodAmount > 0, "IBA");
        
        uint256 amountMultiplier = bloodAmount / 200;
        if (amountMultiplier == 0) {
            amountMultiplier = 1;
        }
        
        return (config.basePoints * config.weight * amountMultiplier) / 100;
    }
    
    function isValidStatusTransition(uint8 from, uint8 to) internal pure returns (bool) {
        if (from == 0 && (to == 1 || to == 3)) return true;
        if (from == 1 && (to == 2 || to == 3)) return true;
        if (from == 2 && to == 4) return true;
        if (from == 4 && (to == 5 || to == 7)) return true;
        if (from == 5 && (to == 6 || to == 7)) return true;
        if (to == 7) return true;
        return false;
    }
    
    function isAnnualContinuousDonation(address donorAddress) internal view returns (bool) {
        uint64[] memory ids = donorBloodIds[donorAddress];
        if (ids.length < 3) return false;
        
        uint256 count = 0;
        uint256 oneYearAgo = block.timestamp - 365 days;
        
        for (uint256 i = 0; i < ids.length; i++) {
            if (bloodUnits[ids[i]].donationTime >= oneYearAgo) {
                count++;
                if (count >= 3) return true;
            }
        }
        
        return false;
    }
    
    // ==================== Helper Functions ====================
    
    function getStatusName(uint8 status) external pure returns (string memory) {
        if (status == 0) return "Donated";
        if (status == 1) return "Testing";
        if (status == 2) return "Qualified";
        if (status == 3) return "Unqualified";
        if (status == 4) return "Stored";
        if (status == 5) return "Distributed";
        if (status == 6) return "Used";
        if (status == 7) return "Expired";
        return "Unknown";
    }
    
    function createPatientInfoHash(string calldata patientInfo) external pure returns (bytes32) {
        return keccak256(abi.encode(patientInfo));
    }
    
    function getBloodCount() external view returns (uint64) {
        return bloodIdCounter - 1;
    }
    
    function isAuthorizedForBlood(uint64 bloodId, address user) external view returns (bool) {
        BloodUnit memory blood = bloodUnits[bloodId];
        if (blood.bloodId == 0) return false;
        
        return user == blood.donorAddress ||
               queryAuthorizations[blood.donorAddress][user] ||
               authorizedInstitutions[user] ||
               authorizedHospitals[user];
    }
}