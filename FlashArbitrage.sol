// SPDX-License-Identifier: MIT
// Nico's Flash Arbitrage Scanner - Polygon
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Router {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
}

/// @title Quick Arbitrage Checker
/// @notice Scans DEXes on Polygon for profitable arbitrage opportunities
contract NicoArbitrageScanner {
    
    struct Opportunity {
        address tokenIn;
        address tokenOut;
        address dexBuy;
        address dexSell;
        uint256 profitBps;
        uint256 estimatedProfit;
    }
    
    mapping(address => bool) public supportedDex;
    Opportunity[] public lastScan;
    
    event ArbitrageFound(address indexed token, uint256 profitBps, address dexBuy, address dexSell);
    
    constructor(address[] memory _dexs) {
        for (uint i = 0; i < _dexs.length; i++) {
            supportedDex[_dexs[i]] = true;
        }
    }
    
    /// @notice Scan for arbitrage between two tokens across registered DEXes
    function scanPair(
        address tokenIn,
        address tokenOut,
        address[] calldata routers,
        uint256 amountIn
    ) external returns (Opportunity[] memory) {
        delete lastScan;
        
        for (uint i = 0; i < routers.length; i++) {
            if (!supportedDex[routers[i]]) continue;
            
            for (uint j = 0; j < routers.length; j++) {
                if (i == j || !supportedDex[routers[j]]) continue;
                
                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = tokenOut;
                
                try IUniswapV2Router(routers[i]).getAmountsOut(amountIn, path) returns (uint[] memory buyAmounts) {
                    path[0] = tokenOut;
                    path[1] = tokenIn;
                    
                    try IUniswapV2Router(routers[j]).getAmountsOut(buyAmounts[1], path) returns (uint[] memory sellAmounts) {
                        if (sellAmounts[1] > amountIn) {
                            uint256 profit = sellAmounts[1] - amountIn;
                            uint256 profitBps = (profit * 10000) / amountIn;
                            
                            lastScan.push(Opportunity({
                                tokenIn: tokenIn,
                                tokenOut: tokenOut,
                                dexBuy: routers[i],
                                dexSell: routers[j],
                                profitBps: profitBps,
                                estimatedProfit: profit
                            }));
                            
                            emit ArbitrageFound(tokenIn, profitBps, routers[i], routers[j]);
                        }
                    } catch {}
                } catch {}
            }
        }
        
        return lastScan;
    }
    
    /// @notice Get last scan results
    function getLastScan() external view returns (Opportunity[] memory) {
        return lastScan;
    }
}
