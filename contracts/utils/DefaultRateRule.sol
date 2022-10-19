//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IRateRule.sol";
contract DefaultRateRule is IRateRule {
    function getSalePriceDiscount(uint128 buyCount) external pure virtual returns (uint256) {
        if (buyCount > 0) return 5;
        return 2;
    }

    function getCommissionRate(uint128 invitesCount) public pure virtual returns (uint256) {
        if (invitesCount < 5) return 10;
        return 15;
    }
}