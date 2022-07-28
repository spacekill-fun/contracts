// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./Ownable.sol";
import "./IRiskControlStrategy.sol";

contract GameVault is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public admins;
    IRiskControlStrategy riskControlStrategy;

    struct TokenBalance {
        address token;
        uint256 balance;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "!admin");
        _;
    }

    constructor() {
        admins[msg.sender] = true;
    }

    function batchWithdraw(address token, address payable[] memory recipients, uint[] memory amounts) external onlyAdmin {
        require(recipients.length == amounts.length, "recipient & amount arrays must be the same length");
        for (uint i; i < recipients.length; i++) {
            withdrawInternal(token, recipients[i], amounts[i]);
        }  
    }

    function batchWithdraw(address[] memory tokens, address payable[] memory recipients, uint[] memory amounts) external onlyAdmin {
        require(tokens.length == recipients.length && recipients.length == amounts.length, "inconsistent length");
        for (uint i; i < recipients.length; i++) {
            withdrawInternal(tokens[i], recipients[i], amounts[i]);
        }  
    }

    function withdraw(address token, address payable recipient, uint256 amount) external onlyAdmin {
        require(!riskControlStrategy.isRisky(token, recipient, amount), "risky operation");

        withdrawInternal(token, recipient, amount);
    }

    function withdrawInternal(address token, address payable recipient, uint256 amount) internal {
        if (address(token) == address(0x0)) {
            Address.sendValue(recipient, amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    function setRiskControlStrategy(IRiskControlStrategy _riskControlStrategy) external onlyOwner {
        riskControlStrategy = _riskControlStrategy;
    }

    function getTokenBalance(address token) view public returns (uint256) {
        if (token == address(0x0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    function getTokenBalances(address[] memory tokens) view external returns (TokenBalance[] memory) {
        TokenBalance[] memory tokenBalances = new TokenBalance[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenBalances[i].token = tokens[i];
            tokenBalances[i].balance = getTokenBalance(tokens[i]);
        }
        return tokenBalances;
    }



    receive() external payable {
    }
}