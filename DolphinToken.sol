// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DolphinToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 499_999_999 * 10 ** 18;
    uint256 public constant FEE_DENOMINATOR = 10_000;

    uint256 public buyTreasuryFee = 100;     // 1%

    uint256 public sellLiquidityFee = 100;   // 1%
    uint256 public sellTreasuryFee = 100;    // 1%

    uint256 public constant MAX_BUY_FEE = 300;   // 3%
    uint256 public constant MAX_SELL_FEE = 500;  // 5%

    bool public tradingEnabled;

    uint256 public pendingLiquidityTokens;
    uint256 public pendingTreasuryTokens;

    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;

    event TradingEnabled();
    event PairUpdated(address indexed pair, bool indexed enabled);
    event FeesUpdated(
        uint256 buyTreasuryFee,
        uint256 sellLiquidityFee,
        uint256 sellTreasuryFee
    );
    event FeeTokensWithdrawn(
        address indexed to,
        uint256 liquidityTokens,
        uint256 treasuryTokens
    );

    constructor() ERC20("Dolphin Token", "DOLPHIN") Ownable(msg.sender) {
        isExcludedFromFees[msg.sender] = true;
        isExcludedFromFees[address(this)] = true;

        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        emit TradingEnabled();
    }

    function setAutomatedMarketMakerPair(address pair, bool enabled) external onlyOwner {
        require(pair != address(0), "Invalid pair");
        automatedMarketMakerPairs[pair] = enabled;
        emit PairUpdated(pair, enabled);
    }

    function setExcludedFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
    }

    function setFees(
        uint256 _buyTreasuryFee,
        uint256 _sellLiquidityFee,
        uint256 _sellTreasuryFee
    ) external onlyOwner {
        require(_buyTreasuryFee <= MAX_BUY_FEE, "Buy fee too high");
        require(
            _sellLiquidityFee + _sellTreasuryFee <= MAX_SELL_FEE,
            "Sell fee too high"
        );

        buyTreasuryFee = _buyTreasuryFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellTreasuryFee = _sellTreasuryFee;

        emit FeesUpdated(
            _buyTreasuryFee,
            _sellLiquidityFee,
            _sellTreasuryFee
        );
    }

    function withdrawFeeTokens(
        address to,
        uint256 liquidityTokens,
        uint256 treasuryTokens
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        require(liquidityTokens <= pendingLiquidityTokens, "Too many liquidity tokens");
        require(treasuryTokens <= pendingTreasuryTokens, "Too many treasury tokens");

        uint256 total = liquidityTokens + treasuryTokens;

        pendingLiquidityTokens -= liquidityTokens;
        pendingTreasuryTokens -= treasuryTokens;

        _update(address(this), to, total);

        emit FeeTokensWithdrawn(to, liquidityTokens, treasuryTokens);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        if (!tradingEnabled) {
            require(
                isExcludedFromFees[from] || isExcludedFromFees[to],
                "Trading not enabled"
            );
        }

        if (
            amount == 0 ||
            isExcludedFromFees[from] ||
            isExcludedFromFees[to]
        ) {
            super._update(from, to, amount);
            return;
        }

        bool isBuy = automatedMarketMakerPairs[from];
        bool isSell = automatedMarketMakerPairs[to];

        uint256 liquidityAmount;
        uint256 treasuryAmount;

        if (isBuy) {
            treasuryAmount = (amount * buyTreasuryFee) / FEE_DENOMINATOR;
        } else if (isSell) {
            liquidityAmount = (amount * sellLiquidityFee) / FEE_DENOMINATOR;
            treasuryAmount = (amount * sellTreasuryFee) / FEE_DENOMINATOR;
        }

        uint256 totalFee = liquidityAmount + treasuryAmount;

        if (totalFee > 0) {
            pendingLiquidityTokens += liquidityAmount;
            pendingTreasuryTokens += treasuryAmount;

            super._update(from, address(this), totalFee);
            amount -= totalFee;
        }

        super._update(from, to, amount);
    }
}