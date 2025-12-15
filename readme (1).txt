Blood Donation Credit System - Smart Contract Documentation
Project Overview
Blockchain-based blood donation public welfare credit system with blood tracking and credit scoring features.

Files Provided
BloodDonationCredit.sol - Smart contract source code (Solidity 0.8.19+)

BloodDonationCreditABI.json - Contract interface file (required for frontend)

Frontend Tasks (Based on project requirements)
Page 1: Donor Registration Form
Form fields: Name, Blood Type, Donation Type, Blood Amount

Connect MetaMask wallet

Call registerDonorAndBlood() function

Display transaction result and blood ID

Page 2: Authorization Management
Authorize addresses to query your data (authorizeQuery())

View authorized addresses

Revoke authorization

Page 3: Blood Query Page
Input blood ID to query details (getBloodInfo())

Display blood status and transfer history

Credit points query (getTotalPoints())

Quick Start for Frontend
1. Install Dependencies
npx create-react-app blood-donation-frontend
cd blood-donation-frontend
npm install web3
2. Connect Contract
import Web3 from 'web3';
import contractABI from './BloodDonationCreditABI.json';

const web3 = new Web3(window.ethereum);
const contractAddress = "0x..."; // Will be provided after testnet deployment
const contract = new web3.eth.Contract(contractABI, contractAddress);
3. Key Functions Examples
Register Donation
const registerDonation = async (bloodType, donationType, bloodAmount) => {
    const accounts = await web3.eth.getAccounts();
    return contract.methods.registerDonorAndBlood(
        accounts[0],
        bloodType,
        donationType,
        bloodAmount
    ).send({ from: accounts[0] });
};
Query Blood Info
const getBloodInfo = async (bloodId) => {
    return contract.methods.getBloodInfo(bloodId).call();
};
Query Credit Points
const getPoints = async () => {
    const accounts = await web3.eth.getAccounts();
    const points = await contract.methods.getTotalPoints(accounts[0]).call();
    const level = await contract.methods.queryCreditLevel(accounts[0]).call();
    return { points, level };
};
Blood Status Codes
0: Donated

1: Testing

2: Qualified

3: Unqualified

4: Stored

5: Distributed

6: Used

7: Expired

Donation Types
whole_blood_200ml (100 points)

whole_blood_400ml (200 points)

component_blood (180 points)

emergency_donation (300 points)

rare_blood_type (324 points)


Testing
Use Remix JavaScript VM for local testing

Get Ropsten test ETH from faucet

Connect MetaMask to Ropsten network

Test all functions end-to-end

Error Codes Reference
OW: Only owner

NI: Not authorized institution

BNE: Blood not exists

NAQ: Not authorized to query

IDT: Invalid donation type