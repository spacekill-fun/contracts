// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract BatchTransfer {
    function batchTransfer(IERC20 token, address payable[] memory recipients, uint[] memory amounts) external payable returns (bool) {
        
        require(recipients.length == amounts.length, "recipient & amount arrays must be the same length");

        if (msg.value > 0) {
            for (uint i; i < recipients.length; i++) {
                Address.sendValue(recipients[i], amounts[i]);
            }
        } else {
            for (uint i; i < recipients.length; i++) {
                require(token.transferFrom(msg.sender, recipients[i], amounts[i]));
            }
        }
    
        return true;
    }
}