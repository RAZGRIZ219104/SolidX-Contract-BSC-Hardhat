// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Quote.sol";

contract DealContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Quote for address;
    using Quote for uint256;

    struct Deal {
        bytes32 id;
        address creator;
        address partner;
        address sellingToken;
        address buyingToken;
        uint256 sellingAmount;
        uint256 buyingAmount;
        uint256 createdAt;
        uint8 status; //0: Not created, 1: Opened, 2: Pending, 3: Approved, 4: Cancelled
    }

    mapping(bytes32 => Deal) private _deals;
    mapping(address => bytes32[]) private _dealsForWallet;

    IERC20 private _feeToken;
    address immutable _usdc;

    uint24 private _feePercentage;
    uint256 private _totalFeeAmount;
    uint256 private _minimumFeeAmountInUSD;
    uint256 private _maximumFeeAmountInUSD;
    uint256 private _dealDuration;
    
    bool private isLive;

    event CreateDeal(address creator_, bytes32 dealId_);
    event JoinDeal(address partner_, bytes32 dealId_);
    event ApproveDeal(bytes32 dealId_);
    event CancelDeal(address canceller_, bytes32 dealId_);

    modifier _requireDealParticipant(bytes32 dealId_) {
        require(
            _msgSender() == _deals[dealId_].creator || _msgSender() == _deals[dealId_].partner,
            "Solidx: not a deal party"
        );
        _;
    }

    constructor(address usdc_, IERC20 feeToken_) {
        _feeToken = feeToken_;
        _usdc = usdc_;
        _feePercentage = 50; // (50 / 10000 = 0.5%)
        _minimumFeeAmountInUSD = 5 * 10 ** 18; // BSC USDC Decimal
        _maximumFeeAmountInUSD = 250 * 10 ** 18; // BSC USDC Decimal
        _dealDuration = 7200; // 2 hrs
        isLive = true;
    }

    function killContract() public onlyOwner {
        require(isLive == true, "Dead already");
        isLive = false;
    }

    function feeToken() public view returns (address) {
        return address(_feeToken);
    }

    function minimumFeeAmountInUSD() public view returns (uint256) {
        return _minimumFeeAmountInUSD;
    }

    function maximumFeeAmountInUSD() public view returns (uint256) {
        return _maximumFeeAmountInUSD;
    }

    function getUSDCtoSOLIDX() public view returns (uint256) {
        uint256 res = _usdc.quoteToSDX(1 * 10 ** 18); // BSC USDC decimal
        return res;
    }

    function getFeeAmount(address origin, uint256 amount) public view returns (uint256) {
        uint256 minQuote = _usdc.quoteToSDX(_minimumFeeAmountInUSD);
        uint256 maxQuote = _usdc.quoteToSDX(_maximumFeeAmountInUSD);
        uint256 quote = (origin.quoteToSDX(amount) * _feePercentage) / 10000;
        quote = quote < minQuote ? minQuote : quote;
        quote = quote > maxQuote ? maxQuote : quote;
        return quote;
    }

    function dealDuration() public view returns (uint256) {
        return _dealDuration;
    }

    function dealCounts() external view returns (uint256 _count) {
        return _dealsForWallet[_msgSender()].length;
    }

    function dealIdAt(uint256 index_) external view returns (bytes32) {
        return _dealsForWallet[_msgSender()][index_];
    }

    function dealAt(
        bytes32 dealId_
    ) public view _requireDealParticipant(dealId_) returns (Deal memory) {
        return _deals[dealId_];
    }

    function dealIds(
        uint256 from_,
        uint8 count_,
        bool status_
    ) public view returns (bytes32[] memory, uint8, uint256) {
        uint256 length = _dealsForWallet[_msgSender()].length;

        require(from_ < length, "Solidx: out of range");

        bytes32[] memory dealIdsSlice = new bytes32[](count_);
        uint256 index = from_;
        uint8 count = 0;
        while (index < length && count < count_) {
            bytes32 id = _dealsForWallet[_msgSender()][length - index - 1];
            if (status_ == true && _deals[id].status >= 3) {
                dealIdsSlice[count] = _dealsForWallet[_msgSender()][length - index - 1];
                count++;
            }
            if (status_ == false && _deals[id].status < 3 && _deals[id].status > 0) {
                dealIdsSlice[count] = _dealsForWallet[_msgSender()][length - index - 1];
                count++;
            }
            index++;
        }

        return (dealIdsSlice, count, index);
    }

    function dealInfoBatch(
        uint256 from_,
        uint8 count_,
        bool status_
    ) public view returns (Deal[] memory, uint256) {
        (bytes32[] memory ids, uint8 count, uint256 lastIndex) = dealIds(from_, count_, status_);
        require(count > 0, "Solidx: nothing to return");

        Deal[] memory dealsSlice = new Deal[](count);
        uint8 index = 0;
        while (index < count) {
            dealsSlice[index] = _deals[ids[index]];
            index++;
        }

        return (dealsSlice, lastIndex);
    }

    function setFeeToken(address feeToken_) external onlyOwner {
        _feeToken = IERC20(feeToken_);
    }

    function setMinimumFeeAmountInUSD(uint256 feeAmount_) external onlyOwner {
        _minimumFeeAmountInUSD = feeAmount_;
    }

    function setMaximumFeeAmountInUSD(uint256 feeAmount_) external onlyOwner {
        _maximumFeeAmountInUSD = feeAmount_;
    }

    function setDealDuration(uint256 durationHours_) external onlyOwner {
        _dealDuration = 60 * 60 * durationHours_;
    }

    function setFeePercentage(uint24 feePercentage_) external onlyOwner {
        _feePercentage = feePercentage_;
    }

    function withdrawFee() external onlyOwner {
        require(_totalFeeAmount > 0);
        _feeToken.safeTransfer(_msgSender(), _totalFeeAmount);
    }

    function createDeal(
        address partner_,
        address sellingToken_,
        address buyingToken_,
        uint256 sellingAmount_,
        uint256 buyingAmount_
    ) external payable {
        uint256 previousCountOfCreator = _dealsForWallet[_msgSender()].length;
        uint256 previousCountOfPartner = _dealsForWallet[partner_].length;
        uint256 quote = getFeeAmount(sellingToken_, sellingAmount_);

        require(isLive == true, "Dead Contract");
        require(partner_ != address(0), "Solidx: partner must be a non-zero address");

        bytes32 dealId = keccak256(abi.encodePacked(_msgSender(), partner_, block.timestamp));

        if (sellingToken_ != address(0)) {
            IERC20(sellingToken_).safeTransferFrom(_msgSender(), address(this), sellingAmount_);
        } else {
            require(msg.value == sellingAmount_, "Solidx: insufficient ether value");
        }

        _totalFeeAmount += quote;
        _feeToken.safeTransferFrom(_msgSender(), address(this), quote);

        Deal storage deal = _deals[dealId];

        require(deal.status == 0, "Solidx: already created");

        deal.id = dealId;
        deal.creator = _msgSender();
        deal.partner = partner_;
        deal.sellingToken = sellingToken_;
        deal.buyingToken = buyingToken_;
        deal.sellingAmount = sellingAmount_;
        deal.buyingAmount = buyingAmount_;
        deal.createdAt = block.timestamp;
        deal.status = 1; //Deal is Opened

        _dealsForWallet[_msgSender()].push(dealId);
        _dealsForWallet[partner_].push(dealId);

        require(
            previousCountOfCreator + 1 == _dealsForWallet[_msgSender()].length &&
                previousCountOfPartner + 1 == _dealsForWallet[partner_].length
        );

        emit CreateDeal(_msgSender(), dealId);
    }

    function joinDeal(bytes32 dealId_) external payable {
        Deal storage deal = _deals[dealId_];

        require(isLive == true, "Dead Contract");
        require(_msgSender() == deal.partner, "Solidx: not a partner");
        require(deal.status == 1, "Solidx: deal is off");

        deal.status = 2; //Deal is Pending
        if (deal.buyingToken != address(0)) {
            IERC20(deal.buyingToken).safeTransferFrom(
                _msgSender(),
                address(this),
                deal.buyingAmount
            );
        } else {
            require(msg.value == deal.buyingAmount, "Solidx: insufficient ether value");
        }

        emit JoinDeal(_msgSender(), dealId_);
    }

    function approveDeal(bytes32 dealId_) external nonReentrant {
        Deal storage deal = _deals[dealId_];

        require(isLive == true, "Dead Contract");
        require(_msgSender() == deal.creator, "Solidx: not a creator");
        require(deal.status == 2, "Solidx: deal is not pending");

        deal.status = 3; //Deal is approved

        if (deal.sellingToken != address(0)) {
            IERC20(deal.sellingToken).safeTransfer(deal.partner, deal.sellingAmount);
        } else {
            payable(deal.partner).transfer(deal.sellingAmount);
        }

        if (deal.buyingToken != address(0)) {
            IERC20(deal.buyingToken).safeTransfer(deal.creator, deal.buyingAmount);
        } else {
            payable(deal.creator).transfer(deal.buyingAmount);
        }

        emit ApproveDeal(dealId_);
    }

    function cancelDeal(bytes32 dealId_) external nonReentrant {
        Deal storage deal = _deals[dealId_];

        require(isLive == true, "Dead Contract");
        require(
            _msgSender() == deal.creator || _msgSender() == deal.partner,
            "Solidx: invalid user"
        );
        require(block.timestamp > deal.createdAt + _dealDuration, "Solidx: deal is not off");

        if (deal.sellingToken != address(0)) {
            IERC20(deal.sellingToken).safeTransfer(deal.creator, deal.sellingAmount);
        } else {
            payable(deal.creator).transfer(deal.sellingAmount);
        }

        if (deal.status == 2) {
            if (deal.buyingToken != address(0)) {
                IERC20(deal.buyingToken).safeTransfer(deal.partner, deal.buyingAmount);
            } else {
                payable(deal.partner).transfer(deal.buyingAmount);
            }
        }

        deal.status = 4; //Deal is Cancelled!
        // _feeToken.safeTransfer(deal.creator, _feeAmount);

        emit CancelDeal(_msgSender(), dealId_);
    }

    receive() external payable {}
}
