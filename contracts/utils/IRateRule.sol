//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRateRule {
    function getSalePriceDiscount(uint128 buyCount) external view returns (uint256);
    function getCommissionRate(uint128 invitesCount) external view returns (uint256);
}