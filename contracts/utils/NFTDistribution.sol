//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "./IRateRule.sol";

contract NFTDistribution is ERC721Holder, Ownable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        address user;
        uint128 buyCount;
        uint128 invitesCount;
        uint256 commission;
        bool inTopCommissions;
        uint256 topCommissionIndex;
    }

    struct PreSaleConfig {
        uint256 endTime;
        uint256 discountRate;
    }

    struct Ticker {
        address buyer;
        uint256 nftId;
        uint256 timestamp;
    }

    struct RateRule {
        bool isActive;
        IRateRule rateRule;
    }
 
    uint32 public fromTokenId;
    uint32 public toTokenId;
    uint32 public currentTokenId;
    uint128 public salePrice;
    address public fundMgr;
    bool public saleActive = false;

    mapping(uint256 => bool) public uncommonNft;
    mapping(address => uint256[]) public preSaledNfts;
    mapping(uint256 => address) public preSaledNftOwner;
    mapping(uint256 => bool) public preSaledNftClaimed;

    PreSaleConfig public preSaleConfig;
    IRateRule public defaultRateRule;
    
    IERC20 public tradeToken;
    IERC721 public nftToken;

    mapping(address => UserInfo) public userInfo;
    mapping(bytes32 => RateRule) public specialRateRule;
    uint256 public configuredTopCommissionNum = 50;
    UserInfo[] public topCommissions;
    Ticker[] public commonNftTickers;
    Ticker[] public uncommonNftTickers;
    
    error NotWhitelisted();

    event RolledOver(bool status);
    event Claimed(address indexed claimer, address indexed inviter, uint256 tokenId);
    event PreSaled(address indexed claimer, address indexed inviter, uint256 tokenId);
    event PreSaleClaimed(address indexed claimer, uint256 tokenId);

    constructor(address _fundMgr, address _nftToken) {
        fundMgr = _fundMgr;
        nftToken = IERC721(_nftToken);
    }

    function claimWithInviter(address inviter) external payable {
        address buyer = msg.sender;
        require(saleActive, "Not started");
        require(msg.sender == tx.origin, "Bot not allowed");
        require(currentTokenId <= toTokenId, "Sold out");

        internalClaim(buyer, inviter, "");
    }

    function claimWithProof(address inviter, bytes32 proofRoot, bytes32[] memory proofPath) external payable {
        address buyer = msg.sender;
        require(saleActive, "Not started");
        require(msg.sender == tx.origin, "Bot not allowed");
        require(currentTokenId <= toTokenId, "Sold out");
        require(specialRateRule[proofRoot].isActive, "Invalid proof root");
        // verify merkle proof
        bool isValid = verifyProof(inviter, proofRoot, proofPath);
        if(!isValid) revert  NotWhitelisted();

        internalClaim(buyer, inviter, proofRoot);        
    }

    function internalClaim(address buyer, address inviter, bytes32 proofRoot) internal {
        IRateRule rateRule = defaultRateRule;
        if (proofRoot != "") {
            rateRule = specialRateRule[proofRoot].rateRule;
        }
        Ticker memory ticker = Ticker(buyer, currentTokenId, block.timestamp);
        updateTickers(ticker);

        if (userInfo[buyer].user == address(0x0)) {
            userInfo[buyer].user = buyer;
        }

        userInfo[buyer].buyCount++;
        uint256 feeToPay = getCurrentSalePrice(buyer, inviter, rateRule);

        if (isNativeToken(tradeToken)) {
            require(msg.value == feeToPay, "Invalid pay");
        } else {
            require(msg.value == 0, "Invalid pay");
            tradeToken.safeTransferFrom(buyer, address(this), feeToPay);
        }

        if (buyer != inviter && inviter != address(0x0)) {
            if (userInfo[inviter].user == address(0x0)) {
                userInfo[inviter].user = inviter;
            }
            userInfo[inviter].invitesCount++;
            uint256 commissionRate = rateRule.getCommissionRate(userInfo[inviter].invitesCount);
            uint256 commissionToPay = salePrice * commissionRate / 100;
            userInfo[inviter].commission += commissionToPay;
            updateTopCommissions(userInfo[inviter]);

            if (isNativeToken(tradeToken)) {
                payable(inviter).transfer(commissionToPay);
            } else {
                tradeToken.safeTransfer(inviter, commissionToPay);
            }
        }
        
        if (isPreSaleTime()) {
            preSaledNfts[buyer].push(currentTokenId);
            preSaledNftOwner[currentTokenId] = buyer;
            emit PreSaled(buyer, inviter, currentTokenId);
        } else {
            nftToken.safeTransferFrom(address(this), buyer, currentTokenId); 
            emit Claimed(buyer, inviter, currentTokenId);
        }
        currentTokenId = currentTokenId + 1;
    }

    function claimPreSaledNfts(uint256[] calldata nftIds) external {
        require(!isPreSaleTime(), "Pre sale not end");

        address buyer = msg.sender;
        for (uint256 i = 0; i < nftIds.length; i++) {
            if (preSaledNftOwner[nftIds[i]] == buyer && !preSaledNftClaimed[nftIds[i]]) {
                preSaledNftClaimed[nftIds[i]] = true;
                nftToken.safeTransferFrom(address(this), buyer, nftIds[i]);
                emit PreSaleClaimed(buyer, nftIds[i]);
            }
        }
    }

    function withdraw(IERC20 token) external {
        if (address(token) == address(0x0)) {
            payable(fundMgr).transfer(address(this).balance);
            return;
        }

        token.safeTransfer(fundMgr, token.balanceOf(address(this)));
    }

    function isNativeToken(IERC20 token) internal pure returns (bool) {
        if (address(token) == address(0x0)) return true;
        return false;
    }

    function verifyProof(address user, bytes32 proofRoot, bytes32[] memory proofPath) public pure returns(bool){
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bool isValid = MerkleProof.verify(proofPath, proofRoot, leaf);
        return isValid;
    }

    function updateTopCommissions(UserInfo memory updatedUserInfo) internal {
        if (topCommissions.length == 0) {
            updatedUserInfo.inTopCommissions = true;
            updatedUserInfo.topCommissionIndex = 0;
            topCommissions.push(updatedUserInfo);
            return;
        }

        if (topCommissions.length > configuredTopCommissionNum) {
            if (updatedUserInfo.commission < topCommissions[configuredTopCommissionNum - 1].commission) {
                return;
            }
            if (updatedUserInfo.inTopCommissions) {
                topCommissions[updatedUserInfo.topCommissionIndex] = updatedUserInfo;
            } else {
                topCommissions[configuredTopCommissionNum] = updatedUserInfo;
            }
        } else {
            if (updatedUserInfo.inTopCommissions) {
                topCommissions[updatedUserInfo.topCommissionIndex] = updatedUserInfo;
            } else {
                updatedUserInfo.topCommissionIndex = topCommissions.length;
                updatedUserInfo.inTopCommissions = true;
                topCommissions.push(updatedUserInfo);
            }
        }
        
        UserInfo[] memory temp = topCommissions;
        sort(temp);
        for (uint i = 0; i < temp.length; i++) {
            temp[i].topCommissionIndex = i;
            topCommissions[i] = temp[i];
            userInfo[temp[i].user] = temp[i];
        }
    }

    function getTopCommissions() external view returns (UserInfo[] memory) {
        return topCommissions;
    }

    function getUserPreSaledNfts(address user) external view returns (uint256[] memory) {
        return preSaledNfts[user];
    }

    function getLatestBoughtCommonNfts() external view returns(Ticker[] memory) {
        return commonNftTickers;
    }

    function getLastestBoughtUncommonNfts() external view returns(Ticker[] memory) {
        return uncommonNftTickers;
    }

    function getCurrentSalePrice(address buyer, address inviter, IRateRule currentRateRule) public view returns (uint256) {
        if (isPreSaleTime()) {
            return salePrice - salePrice * preSaleConfig.discountRate / 100;
        }

        if (buyer == inviter || inviter == address(0x0)) return salePrice;

        return salePrice - salePrice * currentRateRule.getSalePriceDiscount(userInfo[inviter].buyCount) / 100;
    }

    function getSalePriceDiscount(address inviter, bytes32 proofRoot) external view returns(uint256) {
        if (isPreSaleTime()) {
            return preSaleConfig.discountRate;
        }
        if (inviter == address(0x0)) {
            return 0;
        }
        IRateRule rateRule = defaultRateRule;
        if (proofRoot != "") {
            rateRule = specialRateRule[proofRoot].rateRule;
        }
        return rateRule.getSalePriceDiscount(userInfo[inviter].buyCount);
    }

    function isPreSaleTime() public view returns (bool) {
        return block.timestamp <= preSaleConfig.endTime;
    }

    function getCommissionRate(uint128 invitesCount) public view returns (uint256) {
        return defaultRateRule.getCommissionRate(invitesCount);
    }

    function updateTickers(Ticker memory ticker) internal {
        if (uncommonNft[ticker.nftId]) {
            if (uncommonNftTickers.length < 3) {
                uncommonNftTickers.push(ticker);
            } else {
                tickerSwap(uncommonNftTickers, 0, 1);
                tickerSwap(uncommonNftTickers, 1, 2);
                uncommonNftTickers[2] = ticker;
            }
            return;
        }
        if (commonNftTickers.length < 3) {
            commonNftTickers.push(ticker);
        } else {
            tickerSwap(commonNftTickers, 0, 1);
            tickerSwap(commonNftTickers, 1, 2);
            commonNftTickers[2] = ticker;
        }
    }

    function tickerSwap(Ticker[] memory tickers, uint256 i, uint256 j) pure internal {
        (tickers[i], tickers[j]) = (tickers[j], tickers[i]);
    }

    //==================== Admin Functions ===================
    function setUncommonNFTs(uint256[] calldata nftIds, bool isUncommon) external onlyOwner {
        for (uint256 i = 0; i < nftIds.length; i++) {
            uncommonNft[nftIds[i]] = isUncommon;
        }
    }

    function configPreSale(uint256 endTime, uint256 discountRate) external onlyOwner {
        preSaleConfig.endTime = endTime;
        preSaleConfig.discountRate = discountRate;
    }

    function setDefaultRateRule(IRateRule newRateRule) external onlyOwner {
        defaultRateRule = newRateRule;
    }

    function setSpecialRateRule(bytes32 proofRoot, IRateRule newRateRule) external onlyOwner {
        specialRateRule[proofRoot].rateRule = newRateRule;
        specialRateRule[proofRoot].isActive = true;
    }

    function setTradeToken(IERC20 newTradeToken) external onlyOwner {
        tradeToken = newTradeToken;
    }

    function setTokenScope(uint32 _fromTokenId, uint32 _toTokenId) external onlyOwner {
        require(_toTokenId >= _fromTokenId, "Invalid token scope");

        fromTokenId = _fromTokenId;
        toTokenId = _toTokenId;
        if (currentTokenId < _fromTokenId) {
            currentTokenId = _fromTokenId;
        }
    }

    function flipSaleStatus() external onlyOwner {
        saleActive = !saleActive;

        emit RolledOver(saleActive);
    }

    function setSalePrice(uint128 _salePrice) external onlyOwner {
        salePrice = _salePrice;
    }

    function updateFundMgr(address newFundMgr) external onlyOwner {
        fundMgr = newFundMgr;
    }

    // ========== Heap Sort Implementation ==========
    function sort(UserInfo[] memory _input) public pure returns (UserInfo[] memory) {
        _buildMaxHeap(_input);

        uint256 length = _input.length;
        unchecked {
            for (uint256 i = length - 1; i > 0; --i) {
                _swap(_input, 0, i);
                _heapify(_input, i, 0);
            }
        }

        return _input;
    }

    function _buildMaxHeap(UserInfo[] memory _input) internal pure {
        uint256 length = _input.length;

        unchecked {
            for (uint256 i = (length >> 1) - 1; i > 0; --i) {
                _heapify(_input, length, i);
            }
            _heapify(_input, length, 0);
        }
    }

    function _heapify(UserInfo[] memory _input, uint256 _n, uint256 _i) internal pure {
        unchecked {
            uint256 max = _i;
            uint256 left = (_i << 1) + 1;
            uint256 right = (_i << 1) + 2;

            if (left < _n && _input[left].commission < _input[max].commission) {
                max = left;
            }

            if (right < _n && _input[right].commission < _input[max].commission) {
                max = right;
            }

            if (max != _i) {
                _swap(_input, _i, max);
                _heapify(_input, _n, max);
            }
        }
    }

    function _swap(UserInfo[] memory _input, uint256 _i, uint256 _j) internal pure {
        (_input[_i], _input[_j]) = (_input[_j], _input[_i]);
    }
}