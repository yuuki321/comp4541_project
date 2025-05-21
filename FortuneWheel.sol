// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract FortuneWheel {
    // State
    address public immutable gameHost;
    address[] public spinners;
    uint256 public spinCost;
    uint256 public currentRound;
    uint256 public houseFeePercent;
    bool    public spinningActive;

    mapping(address => uint256) public playerSpins;
    mapping(uint256 => address) public roundWinners;
    mapping(address => uint256) public pendingRewards;

    struct PrizeTier {
        uint256 tierChance;   // 1−100
        uint256 tierPercent;  // % of pool
        string  tierName;
    }
    PrizeTier[] public prizeTiers;

    // Events
    event WheelSpun(address indexed spinner, uint256 amount, uint256 round);
    event PrizeWon(address indexed winner, uint256 amount, string tierName, uint256 round);
    event NewRoundStarted(uint256 round, uint256 newSpinCost);
    event HouseFeeCollected(uint256 amount);
    event PrizeStructureUpdated();

    // No-args constructor: defaults 0.001 ETH per spin, 5% house fee
    constructor() {
        gameHost        = msg.sender;
        spinCost        = 0.001 ether;
        currentRound    = 1;
        houseFeePercent = 5;
        spinningActive  = true;

        // Default prize tiers must sum chances=100, percents <=95 total
        prizeTiers.push(PrizeTier(50, 10, "Minor Prize"));
        prizeTiers.push(PrizeTier(30, 25, "Standard Prize"));
        prizeTiers.push(PrizeTier(15, 40, "Major Prize"));
        prizeTiers.push(PrizeTier(5, 75, "Jackpot"));
    }

    modifier onlyHost() {
        require(msg.sender == gameHost, "Only game host");
        _;
    }
    modifier wheelActive() {
        require(spinningActive, "Wheel is paused");
        _;
    }

    // Players pay exactly `spinCost` to spin
    function spinWheel() external payable wheelActive {
        require(msg.value == spinCost, "Wrong spin cost");
        spinners.push(msg.sender);
        playerSpins[msg.sender]++;

        _determineAndAwardPrize(msg.sender);
        emit WheelSpun(msg.sender, msg.value, currentRound);
    }

    function _determineAndAwardPrize(address spinner) private {
        uint256 rnd = _generatePseudoRandom(100);
        uint256 cum = 0;
        for (uint256 i = 0; i < prizeTiers.length; i++) {
            cum += prizeTiers[i].tierChance;
            if (rnd <= cum) {
                // Calculate prize
                uint256 pool    = address(this).balance;
                uint256 prize   = (pool * prizeTiers[i].tierPercent) / 100;
                uint256 maxPay  = (pool * (100 - houseFeePercent)) / 100;
                if (prize > maxPay) prize = maxPay;

                pendingRewards[spinner] += prize;
                emit PrizeWon(spinner, prize, prizeTiers[i].tierName, currentRound);
                break;
            }
        }
    }

    function claimRewards() external {
        uint256 amt = pendingRewards[msg.sender];
        require(amt > 0, "No rewards");
        pendingRewards[msg.sender] = 0;
        (bool ok,) = payable(msg.sender).call{value: amt}("");
        require(ok, "Transfer failed");
    }

    function getAllSpinners() external view returns (address[] memory) {
        return spinners;
    }

    function getSpinnerCount() external view returns (uint256) {
        return spinners.length;
    }

    function getLastWinners(uint256 count) external view returns (address[] memory) {
        uint256 start = currentRound > count ? currentRound - count : 1;
        uint256 len   = currentRound - start;
        address[] memory w = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            w[i] = roundWinners[start + i];
        }
        return w;
    }

    function _generatePseudoRandom(uint256 max) private view returns (uint256) {
        return (
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        msg.sender,
                        spinners.length,
                        blockhash(block.number - 1)
                    )
                )
            ) % max
        ) + 1;
    }

    // Host-only: finish round, collect fee, start new round
    function finalizeRound(uint256 newSpinCost) external onlyHost {
        address champ = _determineRoundChampion();
        roundWinners[currentRound] = champ;

        // Champion bonus
        if (champ != address(0)) {
            uint256 bonus = (address(this).balance * 5) / 100;
            pendingRewards[champ] += bonus;
            emit PrizeWon(champ, bonus, "Champion Bonus", currentRound);
        }

        // Collect house fee
        _collectHouseFee();

        // Reset for new round
        currentRound++;
        spinCost = newSpinCost;
        delete spinners;
        emit NewRoundStarted(currentRound, newSpinCost);
    }

    function _determineRoundChampion() private view returns (address) {
        if (spinners.length == 0) return address(0);
        address best;
        uint256 top;
        for (uint256 i = 0; i < spinners.length; i++) {
            uint256 r = pendingRewards[spinners[i]];
            if (r > top) {
                top  = r;
                best = spinners[i];
            }
        }
        return best;
    }

    function _collectHouseFee() private {
        uint256 fee = (address(this).balance * houseFeePercent) / 100;
        if (fee > 0) {
            (bool ok,) = payable(gameHost).call{value: fee}("");
            require(ok, "Fee transfer failed");
            emit HouseFeeCollected(fee);
        }
    }

    function emergencyFeeCollection() external onlyHost {
        _collectHouseFee();
    }

    function updatePrizeStructure(
        uint256[] calldata chances,
        uint256[] calldata percentages,
        string[]  calldata names
    ) external onlyHost {
        require(
            chances.length == percentages.length &&
            chances.length == names.length,
            "Array length mismatch"
        );

        uint256 sumPct;
        for (uint i; i < percentages.length; i++) sumPct += percentages[i];
        require(sumPct <= 95, "Prize % too high");

        uint256 sumCh;
        for (uint i; i < chances.length; i++) sumCh += chances[i];
        require(sumCh == 100, "Chances must total 100");

        delete prizeTiers;
        for (uint i; i < chances.length; i++) {
            prizeTiers.push(PrizeTier(chances[i], percentages[i], names[i]));
        }
        emit PrizeStructureUpdated();
    }

    function toggleWheelActive() external onlyHost {
        spinningActive = !spinningActive;
    }

    function updateHouseFee(uint256 newFee) external onlyHost {
        require(newFee >= 5 && newFee <= 20, "Fee 5-20%");
        houseFeePercent = newFee;
    }

    function updateSpinCost(uint256 newCost) external onlyHost {
        spinCost = newCost;
    }

    function getCurrentPrizePool() external view returns (uint256) {
        return address(this).balance;
    }
}
