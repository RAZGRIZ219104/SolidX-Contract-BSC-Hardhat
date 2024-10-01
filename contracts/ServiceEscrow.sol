// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Quote.sol";

contract ServiceEscrow is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Quote for address;

    struct Milestone {
        string name;
        string description;
        uint256 amount;
        uint256 deadline;
        uint256 status; // 0:Ongoing, 1:Approved
    }

    struct Service {
        bytes32 id;
        bool isSelling;
        uint256 createdAt;
        string serviceCaption;
        uint256 numberOfMilestones;
        Milestone[] milestones;
        uint256 status; // 0: Not created, 1: Created, 2: Ongoing, 3: Finished, 4: Cancelled
        address creator;
        address partner;
        address paymentToken;
        uint256 totalBudget;
        uint256 paidBudget;
        bool isCreatorApprovedCancel;
        bool isPartnerApprovedCancel;
    }

    mapping(bytes32 => Service) private _services;
    mapping(address => bytes32[]) private _servicesForWallet;
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
    event ApproveMilestone(address buyer_, bytes32 dealId_, uint256 milestoneIndex_);
    event ApproveDeal(address seller_, bytes32 dealId_);
    event CancelDeal(address seller_, bytes32 dealId_);
    event AchieveDeal(address seller_, bytes32 dealId_);

    modifier _requireDealParticipant(bytes32 dealId_) {
        require(
            _msgSender() == _services[dealId_].creator ||
                _msgSender() == _services[dealId_].partner,
            "Solidx: not a service party"
        );
        _;
    }

    constructor(address usdc_, IERC20 feeToken_) {
        _feeToken = feeToken_;
        _usdc = usdc_;
        _feePercentage = 50; // (50 / 10000 = 0.5%)
        _minimumFeeAmountInUSD = 5 * 10 ** 18; // BSC USDC Decimal
        _maximumFeeAmountInUSD = 250 * 10 ** 18; // BSC USDC Decimal
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

    function getFeeAmount(address origin, uint256 amount) public view returns (uint256) {
        uint256 minQuote = _usdc.quoteToSDX(_minimumFeeAmountInUSD);
        uint256 maxQuote = _usdc.quoteToSDX(_maximumFeeAmountInUSD);
        uint256 quote = (origin.quoteToSDX(amount) * _feePercentage) / 10000;
        quote = quote < minQuote ? minQuote : quote;
        quote = quote > maxQuote ? maxQuote : quote;
        return quote;
    }

    function serviceCounts() external view returns (uint256 _count) {
        return _servicesForWallet[_msgSender()].length;
    }

    function serviceIdAt(uint256 index_) external view returns (bytes32) {
        return _servicesForWallet[_msgSender()][index_];
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function serviceAt(
        bytes32 dealId_
    ) public view _requireDealParticipant(dealId_) returns (Service memory) {
        return _services[dealId_];
    }

    function serviceIds(
        uint256 from_,
        uint8 count_,
        bool status_
    ) public view returns (bytes32[] memory, uint8, uint256) {
        uint256 length = _servicesForWallet[_msgSender()].length;

        require(from_ < _servicesForWallet[_msgSender()].length, "Solidx: out of range");

        bytes32[] memory serviceIdsSlice = new bytes32[](count_);
        uint256 index = from_;
        uint8 count = 0;
        while (index < length && count < count_) {
            bytes32 id = _servicesForWallet[_msgSender()][length - index - 1];
            if (status_ == true && _services[id].status >= 3) {
                serviceIdsSlice[count] = _servicesForWallet[_msgSender()][length - index - 1];
                count++;
            }
            if (status_ == false && _services[id].status < 3 && _services[id].status > 0) {
                serviceIdsSlice[count] = _servicesForWallet[_msgSender()][length - index - 1];
                count++;
            }
            index++;
        }

        return (serviceIdsSlice, count, index);
    }

    function serviceInfoBatch(
        uint256 from_,
        uint8 count_,
        bool status_
    ) public view returns (Service[] memory, uint256) {
        (bytes32[] memory ids, uint8 count, uint256 lastIndex) = serviceIds(from_, count_, status_);
        require(count > 0, "Solidx: nothing to return");

        Service[] memory servicesSlice = new Service[](count);
        uint8 index = 0;
        while (index < count) {
            servicesSlice[index] = _services[ids[index]];
            index++;
        }

        return (servicesSlice, lastIndex);
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

    function setFeePercentage(uint24 feePercentage_) external onlyOwner {
        _feePercentage = feePercentage_;
    }

    function withdrawFee() external onlyOwner {
        require(_totalFeeAmount > 0);
        _feeToken.safeTransfer(_msgSender(), _totalFeeAmount);
    }

    function createDeal(
        bool isSelling_,
        string memory caption_,
        uint256 numberOfMilestones_,
        Milestone[] calldata milestones_,
        address partner_,
        address paymentToken_
    ) external payable {
        uint256 previousCountOfCreator = _servicesForWallet[_msgSender()].length;
        uint256 previousCountOfPartner = _servicesForWallet[partner_].length;

        require(isLive == true, "Dead Contract");
        require(partner_ != address(0), "Solidx: partner must be a non-zero address");
        require(
            _isContract(paymentToken_) || paymentToken_ == address(0),
            "Solidx: invalid payment token"
        );

        bytes32 dealId = keccak256(abi.encodePacked(_msgSender(), partner_, block.timestamp));

        Service storage service = _services[dealId];

        require(service.status == 0, "Solidx: already created");

        service.id = dealId;
        service.isSelling = isSelling_;
        service.createdAt = block.timestamp;
        service.serviceCaption = caption_;
        service.numberOfMilestones = numberOfMilestones_;
        service.partner = partner_;
        service.creator = _msgSender();
        service.status = 1; //Deal is created!
        service.paymentToken = paymentToken_;

        _servicesForWallet[_msgSender()].push(dealId);
        _servicesForWallet[partner_].push(dealId);

        for (uint256 i = 0; i < numberOfMilestones_; i++) {
            service.milestones.push(
                Milestone(
                    milestones_[i].name,
                    milestones_[i].description,
                    milestones_[i].amount,
                    milestones_[i].deadline,
                    0
                )
            );
            service.totalBudget += milestones_[i].amount;
        }

        uint256 quote = getFeeAmount(paymentToken_, service.totalBudget);

        _totalFeeAmount += quote;
        _feeToken.safeTransferFrom(_msgSender(), address(this), quote);

        if (!isSelling_) {
            if (paymentToken_ != address(0)) {
                IERC20(paymentToken_).safeTransferFrom(
                    _msgSender(),
                    address(this),
                    service.totalBudget
                );
            } else {
                require(msg.value >= service.totalBudget, "Solidx: insufficient ether value");
            }
        }

        require(
            previousCountOfCreator + 1 == _servicesForWallet[_msgSender()].length &&
                previousCountOfPartner + 1 == _servicesForWallet[partner_].length,
            "Solidx: failed"
        );

        emit CreateDeal(_msgSender(), dealId);
    }

    function joinDeal(bytes32 dealId_) external payable {
        Service storage service = _services[dealId_];

        require(isLive == true, "Dead Contract");
        require(_msgSender() == service.partner, "Solidx: invalid partner");
        require(service.status == 1, "Solidx: service is off");

        service.status = 2; //Ongoing
        if (service.isSelling) {
            if (service.paymentToken != address(0)) {
                IERC20(service.paymentToken).safeTransferFrom(
                    _msgSender(),
                    address(this),
                    service.totalBudget
                );
            } else {
                require(msg.value == service.totalBudget, "Solidx: insufficient ether value");
            }
        }

        emit JoinDeal(_msgSender(), dealId_);
    }

    function approveMilestone(bytes32 dealId_, uint256 milestoneIndex_) external {
        Service storage service = _services[dealId_];
        Milestone storage milestone = _services[dealId_].milestones[milestoneIndex_];

        require(isLive == true, "Dead Contract");
        require(milestone.status == 0, "Solidx: service is approved");

        address seller;

        if (service.isSelling == true) {
            require(service.partner == _msgSender(), "Solidx: invalid approver");
            seller = service.creator;
        } else {
            require(service.creator == _msgSender(), "Solidx: invalid approver");
            seller = service.partner;
        }

        require(seller != address(0), "Solidx: invalid seller");

        milestone.status = 1; // approve milestone
        service.paidBudget += milestone.amount; // plus paid budget
        if (service.totalBudget == service.paidBudget) {
            service.status = 3; // service achieved
            emit AchieveDeal(_msgSender(), dealId_);
        }

        if (service.paymentToken != address(0)) {
            IERC20(service.paymentToken).safeTransfer(seller, milestone.amount);
        } else {
            payable(seller).transfer(milestone.amount);
        }

        emit ApproveMilestone(_msgSender(), dealId_, milestoneIndex_);
    }

    function approveCanncel(bytes32 dealId_) external {
        Service storage service = _services[dealId_];

        require(isLive == true, "Dead Contract");
        require(
            service.creator == _msgSender() || service.partner == _msgSender(),
            "Solidx: not a partner"
        );

        if (service.creator == _msgSender()) {
            require(service.isCreatorApprovedCancel == false, "Solidx: already approved");
            service.isCreatorApprovedCancel = true;
        } else {
            require(service.isPartnerApprovedCancel == false, "Solidx: already approved");
            service.isPartnerApprovedCancel = true;
        }

        emit ApproveDeal(_msgSender(), dealId_);
    }

    function cancelDeal(bytes32 dealId_) external {
        Service storage service = _services[dealId_];

        require(isLive == true, "Dead Contract");
        require(
            service.creator == _msgSender() || service.partner == _msgSender(),
            "Solidx: invalid canceler"
        );

        if (service.status == 2) {
            require(
                service.isCreatorApprovedCancel && service.isPartnerApprovedCancel == true,
                "Solidx: canceling not approved"
            );
        }

        _cancelDeal(dealId_);
    }

    function cancelByAdmin(bytes32 dealId_) external onlyOwner {
        _cancelDeal(dealId_);
    }

    function _cancelDeal(bytes32 dealId_) internal {
        Service storage service = _services[dealId_];

        require(service.status < 3, "Solidx: service is off");

        address buyer = service.isSelling == true ? service.partner : service.creator;

        if (service.status == 1) {
            if (service.paymentToken != address(0)) {
                IERC20(service.paymentToken).safeTransfer(buyer, service.totalBudget);
            } else {
                payable(buyer).transfer(service.totalBudget);
            }
        } else {
            if (service.paymentToken != address(0)) {
                IERC20(service.paymentToken).safeTransfer(
                    buyer,
                    service.totalBudget - service.paidBudget
                );
            } else {
                payable(buyer).transfer(service.totalBudget - service.paidBudget);
            }
        }
        service.status = 4; // cancel the deal

        emit CancelDeal(_msgSender(), dealId_);
    }

    receive() external payable {}
}
