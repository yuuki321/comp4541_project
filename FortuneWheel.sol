// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract FortuneWheel {
    // State variables with unique naming
    address public immutable gameHost;
    address[] public spinners;
    uint256 public spinCost;
    uint256 public currentRound;
    uint256 public houseFeePercent;
    bool public spinningActive;
    
    // Maps to track player stats
    mapping(address => uint256) public playerSpins;
    mapping(uint256 => address) public roundWinners;
    mapping(address => uint256) public pendingRewards;
    
    // Prize tiers (in percentages of total pool)
    // Combined percentages must be <= 95% (5% min house fee)
    struct PrizeTier {
        uint256 tierChance;    // Chance of hitting this tier (1-100)
        uint256 tierPercent;   // Percentage of pool for this tier
        string tierName;       // Name of this tier
    }
    
    PrizeTier[] public prizeTiers;
    
    // Events with different names from sample
    event WheelSpun(address indexed spinner, uint256 amount, uint256 round);
    event PrizeWon(address indexed winner, uint256 amount, string tierName, uint256 round);
    event RoundFinished(uint256 round, address winner, uint256 totalPrize);
    event NewRoundStarted(uint256 round, uint256 newSpinCost);
    event HouseFeeCollected(uint256 amount);
    event PrizeStructureUpdated();
    
    // Constructor with different parameters
    constructor(uint256 _initialSpinCost, uint256 _houseFeePercent) {
        require(_houseFeePercent >= 5 && _houseFeePercent <= 20, "Fee must be 5-20%");
        gameHost = msg.sender;
        spinCost = _initialSpinCost;
        currentRound = 1;
        houseFeePercent = _houseFeePercent;
        spinningActive = true;
        
        // Set up default prize tiers
        prizeTiers.push(PrizeTier(50, 10, "Minor Prize"));      // 50% chance to win 10% of pool
        prizeTiers.push(PrizeTier(30, 25, "Standard Prize"));   // 30% chance to win 25% of pool
        prizeTiers.push(PrizeTier(15, 40, "Major Prize"));      // 15% chance to win 40% of pool
        prizeTiers.push(PrizeTier(5, 75, "Jackpot"));           // 5% chance to win 75% of pool
    }
    
    // Modifiers with different names
    modifier onlyHost() {
        require(msg.sender == gameHost, "Only game host can perform this action");
        _;
    }
    
    modifier wheelActive() {
        require(spinningActive, "Fortune wheel is currently paused");
        _;
    }
    
    // Main function for players to spin the wheel
    function spinWheel() public payable wheelActive {
        require(msg.value == spinCost, "Please pay the exact spin cost");
        
        // Add spinner to the list
        spinners.push(msg.sender);
        playerSpins[msg.sender]++;
        
        // Calculate prize - actual transfer happens in separate function
        _determineAndAwardPrize(msg.sender);
        
        emit WheelSpun(msg.sender, msg.value, currentRound);
    }
    
    // Internal function to calculate prize
    function _determineAndAwardPrize(address spinner) private {
        // Generate random number for prize determination
        uint256 randomValue = _generatePseudoRandom(100);
        uint256 currentValue = 0;
        
        // Determine which prize tier was hit
        for (uint i = 0; i < prizeTiers.length; i++) {
            currentValue += prizeTiers[i].tierChance;
            
            // If random value falls within this tier's range
            if (randomValue <= currentValue) {
                // Calculate prize amount
                uint256 prizeAmount = (address(this).balance * prizeTiers[i].tierPercent) / 100;
                
                // Safety check - don't award more than available minus house fee
                uint256 maxPayout = address(this).balance * (100 - houseFeePercent) / 100;
                if (prizeAmount > maxPayout) {
                    prizeAmount = maxPayout;
                }
                
                // Record prize
                pendingRewards[spinner] += prizeAmount;
                
                emit PrizeWon(spinner, prizeAmount, prizeTiers[i].tierName, currentRound);
                break;
            }
        }
    }
    
    // Function for users to claim their accrued rewards
    function claimRewards() public {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        
        // Reset pending rewards before transfer to prevent reentrancy
        pendingRewards[msg.sender] = 0;
        
        // Transfer rewards
        (bool success, ) = payable(msg.sender).call{value: reward}("");
        require(success, "Failed to transfer rewards");
    }
    
    // Function to get all current spinners
    function getAllSpinners() public view returns (address[] memory) {
        return spinners;
    }
    
    // Function to get the number of spinners
    function getSpinnerCount() public view returns (uint256) {
        return spinners.length;
    }
    
    // Function to get recent winners
    function getLastWinners(uint256 count) public view returns (address[] memory) {
        uint256 startRound = currentRound > count ? currentRound - count : 1;
        uint256 resultCount = currentRound - startRound;
        
        address[] memory winners = new address[](resultCount);
        
        for (uint i = 0; i < resultCount; i++) {
            winners[i] = roundWinners[startRound + i];
        }
        
        return winners;
    }
    
    // Generate pseudo-random number
    function _generatePseudoRandom(uint256 max) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp, 
            block.prevrandao, 
            msg.sender,
            spinners.length,
            blockhash(block.number - 1)
        ))) % max + 1; // 1 to max, not 0 to max-1
    }
    
    // Host functions for managing the wheel
    
    // Complete current round and start new one
    function finalizeRound(uint256 newSpinCost) public onlyHost {
        // Record current round champion (whoever won the most)
        address champion = _determineRoundChampion();
        roundWinners[currentRound] = champion;
        
        // Award additional bonus to the champion
        if (champion != address(0)) {
            uint256 bonusAmount = (address(this).balance * 5) / 100;
            pendingRewards[champion] += bonusAmount;
            emit PrizeWon(champion, bonusAmount, "Champion Bonus", currentRound);
        }
        
        // Collect house fee
        _collectHouseFee();
        
        // Reset for new round
        currentRound++;
        spinCost = newSpinCost;
        delete spinners;
        
        emit NewRoundStarted(currentRound, newSpinCost);
    }
    
    // Calculate who won the most in the current round
    function _determineRoundChampion() private view returns (address) {
        if (spinners.length == 0) return address(0);
        
        address champion = address(0);
        uint256 highestReward = 0;
        
        for (uint i = 0; i < spinners.length; i++) {
            address spinner = spinners[i];
            uint256 reward = pendingRewards[spinner];
            
            if (reward > highestReward) {
                champion = spinner;
                highestReward = reward;
            }
        }
        
        return champion;
    }
    
    // Collect house fee
    function _collectHouseFee() private {
        uint256 feeAmount = (address(this).balance * houseFeePercent) / 100;
        if (feeAmount > 0) {
            (bool success, ) = payable(gameHost).call{value: feeAmount}("");
            require(success, "Failed to transfer house fee");
            emit HouseFeeCollected(feeAmount);
        }
    }
    
    // Emergency fee collection - without ending the round
    function emergencyFeeCollection() public onlyHost {
        _collectHouseFee();
    }
    
    // Update prize structure
    function updatePrizeStructure(
        uint256[] memory chances,
        uint256[] memory percentages,
        string[] memory names
    ) public onlyHost {
        require(chances.length == percentages.length && chances.length == names.length, "Arrays must be same length");
        
        // Validate percentages don't exceed max
        uint256 totalPercent = 0;
        for (uint i = 0; i < percentages.length; i++) {
            totalPercent += percentages[i];
        }
        require(totalPercent <= 95, "Prize percentages too high");
        
        // Validate chances add up to 100
        uint256 totalChance = 0;
        for (uint i = 0; i < chances.length; i++) {
            totalChance += chances[i];
        }
        require(totalChance == 100, "Chances must sum to 100");
        
        // Clear existing tiers
        delete prizeTiers;
        
        // Add new tiers
        for (uint i = 0; i < chances.length; i++) {
            prizeTiers.push(PrizeTier(chances[i], percentages[i], names[i]));
        }
        
        emit PrizeStructureUpdated();
    }
    
    // Toggle wheel active status
    function toggleWheelActive() public onlyHost {
        spinningActive = !spinningActive;
    }
    
    // Update house fee
    function updateHouseFee(uint256 newFeePercent) public onlyHost {
        require(newFeePercent >= 5 && newFeePercent <= 20, "Fee must be 5-20%");
        houseFeePercent = newFeePercent;
    }
    
    // Update spin cost
    function updateSpinCost(uint256 newSpinCost) public onlyHost {
        spinCost = newSpinCost;
    }
    
    // Get current prize pool
    function getCurrentPrizePool() public view returns (uint256) {
        return address(this).balance;
    }
}