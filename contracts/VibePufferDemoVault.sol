// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Vibe Wallet — Puffer 賽道 Sepolia 演示 Vault
/// @notice 簡化版：存入 ETH，按 exchangeRate 鑄造 pufETH-demo 餘額（非主網 Puffer 合約）
contract VibePufferDemoVault {
    string public constant name = "pufETH-demo";
    string public constant symbol = "pufETH";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    /// @dev 每 1 ETH（wei）可鑄造的 pufETH 數量（18 decimals），預設 1:1
    uint256 public exchangeRateWei = 1e18;

    event Deposit(address indexed user, uint256 ethIn, uint256 pufMinted);
    event Withdraw(address indexed user, uint256 pufBurned, uint256 ethOut);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        require(msg.value > 0, "zero");
        uint256 minted = (msg.value * exchangeRateWei) / 1e18;
        balanceOf[msg.sender] += minted;
        totalSupply += minted;
        emit Deposit(msg.sender, msg.value, minted);
    }

    /// @notice 解質押：銷毀 pufETH，按 exchangeRate 取回 ETH
    function withdraw(uint256 pufAmount) external {
        require(pufAmount > 0, "zero");
        require(balanceOf[msg.sender] >= pufAmount, "balance");
        uint256 ethOut = (pufAmount * 1e18) / exchangeRateWei;
        require(address(this).balance >= ethOut, "insolvent");
        balanceOf[msg.sender] -= pufAmount;
        totalSupply -= pufAmount;
        (bool ok, ) = payable(msg.sender).call{value: ethOut}("");
        require(ok, "transfer");
        emit Withdraw(msg.sender, pufAmount, ethOut);
    }

    function setExchangeRate(uint256 newRateWei) external {
        exchangeRateWei = newRateWei;
    }
}
