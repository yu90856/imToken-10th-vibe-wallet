// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Vibe Wallet — Sepolia 演示交換（ETH ↔ vUSDC 1:1）
contract VibeSwapDemo {
    string public constant name = "Vibe Demo USDC";
    string public constant symbol = "vUSDC";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    event Swapped(address indexed user, string direction, uint256 amountIn, uint256 amountOut);

    /// @notice 1 wei ETH → 1 wei vUSDC（演示用，非真實 USDC）
    function swapETHForVUSDC() external payable {
        require(msg.value > 0, "zero");
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Swapped(msg.sender, "ETH_TO_vUSDC", msg.value, msg.value);
    }

    function swapVUSDCForETH(uint256 amount) external {
        require(amount > 0, "zero");
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "transfer");
        emit Swapped(msg.sender, "vUSDC_TO_ETH", amount, amount);
    }

    receive() external payable {}
}
