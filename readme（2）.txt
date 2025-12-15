# Blood Donation Credit System - Smart Contract

## Files
- `BloodDonationCredit.sol` - Smart contract source code
- `BloodDonationCreditABI.json` - Contract ABI for frontend

## Key Features
- Blood donation registration with tracking
- 8-stage blood status management
- Credit points system
- Privacy protection for patient information

## Frontend Tasks
1. React pages: Registration form, Authorization, Query page
2. Connect using Web3.js with provided ABI
3. Deadline: Today 5:00 PM

## Testnet Deployment
Contract address will be provided by 7:00 PM after Ropsten deployment.

## Quick Start
```javascript
import Web3 from 'web3';
import contractABI from './BloodDonationCreditABI.json';

const web3 = new Web3(window.ethereum);
const contractAddress = "0x..."; // Will be provided
const contract = new web3.eth.Contract(contractABI, contractAddress);