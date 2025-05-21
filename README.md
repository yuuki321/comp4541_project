# COMP4541 Project Chan Sheung Yin
# Crypto Fortune Wheel - Decentralized Blockchain Application

## Overview
Crypto Fortune Wheel is a decentralized application (DApp) that implements a probabilistic fortune wheel game on the Ethereum blockchain. Users can spin the wheel for a chance to win different prize tiers, with the potential to win significant portions of the prize pool.

## Directory
/
├─ index.html
├─ FortuneWheel.sol
├─ README.md
├─ Contract_tester_intro.pdf
└─ .nojekyll

## Ethereum Testnet
This project is deployed on the **Sepolia** testnet. Sepolia is an Ethereum testnet that allows for development and testing without using real ETH.

## Live Demo
The application is deployed and available at: [https://hkustfun.github.io/comp4541_project](https://hkustfun.github.io/comp4541_project)

## Smart Contract
The project's smart contract address is: `0xd9145CCE52D386f254917e481eB44e9943F39138`

You can view the contract on Sepolia Etherscan: [https://sepolia.etherscan.io/address/0xd9145CCE52D386f254917e481eB44e9943F39138](https://sepolia.etherscan.io/address/0xd9145CCE52D386f254917e481eB44e9943F39138)

## Features
- Spin the wheel to win prizes in ETH
- Multiple prize tiers with different winning probabilities
- User dashboard showing pending rewards and spin history
- Round-based system with champion bonuses
- Admin controls for game management

## How It Works
1. **Connect Wallet**: Users connect their MetaMask wallet to the application
2. **Spin the Wheel**: Pay a predefined amount of ETH to spin
3. **Win Prizes**: Randomly receive prizes based on probability tiers
4. **Claim Rewards**: Claim your accumulated rewards at any time

## Prize Tiers
- **Minor Prize (50% chance)**: 10% of the pot
- **Standard Prize (30% chance)**: 25% of the pot
- **Major Prize (15% chance)**: 40% of the pot
- **Jackpot (5% chance)**: 75% of the pot

## Game Host Functions
The contract owner (game host) can:
- Finalize rounds and start new ones
- Adjust spin cost
- Modify house fees (5-20% range)
- Pause/resume the wheel
- Collect house fees

## How to Run Locally

### Prerequisites
- Node.js and npm
- MetaMask browser extension
- Some Sepolia testnet ETH (available from faucets)

### Setup
1. Clone the repository:
   ```
   git clone https://github.com/hkustfun/comp4541
   cd comp4541
   ```

2. Install a simple HTTP server if needed:
   ```
   npm install -g http-server
   ```

3. Run the local server:
   ```
   http-server
   ```

4. Open your browser and navigate to:
   ```
   http://localhost:8080
   ```

5. Connect your MetaMask wallet (make sure it's set to Sepolia testnet)

### Smart Contract Deployment
If you want to deploy your own contract:

1. Use Remix (https://remix.ethereum.org/) to compile and deploy the FortuneWheel.sol contract
2. Use the constructor parameters:
   - `_initialSpinCost`: Initial cost to spin in wei (e.g., 1000000000000000 for 0.001 ETH)
   - `_houseFeePercent`: Initial house fee (e.g., 10 for 10%)
3. Update the CONTRACT_ADDRESS in index.html with your new contract address

## Security Considerations
- The random number generation in this contract uses block variables and is pseudorandom. In a production environment, consider using Chainlink VRF for truly random numbers.
- The contract includes withdrawal functions that should be carefully managed.
- Prize tiers are configurable but have safeguards to prevent excessive payouts.

## License
This project is licensed under the MIT License.
