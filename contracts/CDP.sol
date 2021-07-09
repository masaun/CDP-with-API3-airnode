//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { DAI } from "./mock-tokens/DAI.sol";
import { WBTC } from "./mock-tokens/WBTC.sol";

// API3
import { ExampleClient } from "./ExampleClient.sol";


contract CDP is Ownable {
    using SafeMath for uint;

    uint currentLendId;
    uint currentBorrowId;

    // @notice - "Lend" also mean "Collateral" and "Deposit"
    struct Lend {   // Lend ID
        uint daiAmountLended;
        uint startBlock;
        uint endBlock;
    }
    
    struct Borrow {   // Borrow ID 
        uint lendId;  // Because available borrowing amount is based on lending amount 
        uint wbtcAmountBorrowed;
        uint startBlock;
        uint endBlock;
    }

    mapping(address => mapping(uint => Lend)) lends;      // User address -> Lend ID 
    mapping(address => mapping(uint => Borrow)) borrows;  // User address -> Borrow ID 

    // Rate
    uint interestRateForLending = 5;     // APR: 5 (%)  <- Calculated every block
    uint interestRateForBorrowing = 10;  // APR: 10 (%) <- Calculated every block
    uint borrowLimitRate = 50;           // APR: 50 (%) of collateral asset amount

    DAI public dai;
    WBTC public wbtc;

    constructor(DAI _dai, WBTC _wbtc) public {
        dai = _dai;
        wbtc = _wbtc;
    }

    /**
     * @notice - Fund WBTC for initial phase
     */
    function fundWBTC(uint fundWBTCAmount) public onlyOwner returns (bool) {
        wbtc.transferFrom(msg.sender, address(this), fundWBTCAmount);
    }

    /**
     * @notice - Lend DAI as a collateral
     */
    function lendDAI(uint daiAmount) public returns (bool) {
        dai.transferFrom(msg.sender, address(this), daiAmount);

        _lend(daiAmount);
    }

    /**
     * @notice - A user can borrow WBTC until 50% of collateralized-DAI amount
     * @notice - BTC price is retrieved via API3 oracle
     * @param btcPrice - BTC/USD price that is retrieved via API3 oracle. (eg. bitcoin price is 35548 USD)
     */
    function borrowWBTC(uint lendId, uint btcPrice, uint borrowWBTCAmount) public returns (bool) {
        address borrower = msg.sender;

        Lend memory lend = lends[borrower][lendId];
        uint daiAmountLended = lend.daiAmountLended;  // Collateralized-amount
        uint borrowLimit = daiAmountLended.div(btcPrice).mul(borrowLimitRate).div(100);
        require(borrowWBTCAmount <= borrowLimit, "WBTC amount borrowing must be less that the limit amount borrowing");

        wbtc.transfer(borrower, borrowWBTCAmount);

        _borrow(lendId, borrowWBTCAmount);
    }

    function repayWBTC(uint borrowId, uint repaymentAmount) public returns (bool) {
        // Execute repayment
        wbtc.transferFrom(msg.sender, address(this), repaymentAmount);

        // Save repayment
        _repay(borrowId);

        // Calculate interest amount of borrowing by every block
        address borrower = msg.sender;
        Borrow memory borrow = borrows[borrower][borrowId];
        uint wbtcAmountBorrowed = borrow.wbtcAmountBorrowed;  // Principle
        uint startBlock = borrow.startBlock;
        uint endBlock = borrow.endBlock;

        uint OneYearAsSecond = 1 days * 365;
        uint interestRateForBorrowingPerSecond = interestRateForBorrowing.div(OneYearAsSecond);
        uint interestRateForBorrowingPerBlock = interestRateForBorrowingPerSecond.mul(15);  // [Note]: 1 block == 15 seconds
        uint interestAmountForBorrowing = wbtcAmountBorrowed.mul(interestRateForBorrowingPerBlock).div(100).mul(endBlock.sub(startBlock));

        // Update a WBTC amount that msg.sender must repay
        _updateRepaymentAmount(borrowId, repaymentAmount, interestAmountForBorrowing);
    }

    function withdrawDAI(uint lendId, uint withdrawalAmount) public returns (bool) {
        _withdraw(lendId);

        // Calculate earned-interests amount of lending by every block
        address lender = msg.sender;
        Lend memory lend = lends[lender][lendId];
        uint daiAmountLended = lend.daiAmountLended;  // Principle
        uint startBlock = lend.startBlock;
        uint endBlock = lend.endBlock;

        uint OneYearAsSecond = 1 days * 365;
        uint interestRateForLendingPerSecond = interestRateForLending.div(OneYearAsSecond);
        uint interestRateForLendingPerBlock = interestRateForLendingPerSecond.mul(15);  // [Note]: 1 block == 15 seconds
        uint interestAmountForLending = daiAmountLended.mul(interestRateForLendingPerBlock).div(100).mul(endBlock.sub(startBlock));

        // Update a DAI amount that msg.sender lended
        _updateWithdrawalAmount(lendId, withdrawalAmount, interestAmountForLending);
    }


    //------------------
    // Internal methods
    //------------------
    function _lend(uint daiAmountLended) public returns (bool) {
        currentLendId++;
        Lend storage lend = lends[msg.sender][currentLendId];
        lend.daiAmountLended = daiAmountLended;
        lend.startBlock = block.number;
    }

    function _borrow(uint lendId, uint wbtcAmountBorrowed) public returns (bool) {
        currentBorrowId++;
        Borrow storage borrow = borrows[msg.sender][currentBorrowId];
        borrow.lendId = lendId;
        borrow.wbtcAmountBorrowed = wbtcAmountBorrowed;
        borrow.startBlock = block.number;
    }

    function _repay(uint borrowId) public returns (bool) {
        Borrow storage borrow = borrows[msg.sender][borrowId];
        borrow.endBlock = block.number;
    }

    function _updateRepaymentAmount(uint borrowId, uint repaymentAmount, uint interestAmountForBorrowing) public returns (bool) {
        Borrow storage borrow = borrows[msg.sender][borrowId];
        borrow.wbtcAmountBorrowed = repaymentAmount.sub(interestAmountForBorrowing);
    }

    function _updateWithdrawalAmount(uint lendId, uint withdrawalAmount, uint interestAmountForLending) public returns (bool) {
        Lend storage lend = lends[msg.sender][lendId];
        lend.daiAmountLended = withdrawalAmount.sub(interestAmountForLending);
    }

    function _withdraw(uint lendId) public returns (bool) {
        Lend storage lend = lends[msg.sender][lendId];
        lend.endBlock = block.number;
    }

    ///-----------------------------------
    /// Getter methods
    ///-----------------------------------
    function getLend(uint lendId) public view returns (Lend memory _lend) {
        Lend memory lend = lends[msg.sender][lendId];
        return lend;
    }

    function getBorrow(uint borrowId) public view returns (Borrow memory _borrow) {
        Borrow memory borrow = borrows[msg.sender][borrowId];
        return borrow;
    }

    function getRepaymentAmount(uint borrowId) public view returns (uint _repaymentAmount) {
        Borrow memory borrow = borrows[msg.sender][borrowId];
        uint _wbtcAmountBorrowed = borrow.wbtcAmountBorrowed;  /// Principle amount borrowed
        uint _startBlock = borrow.startBlock; 
        uint currentBlock = block.number;

        uint OneYearAsSecond = 1 days * 365;
        uint interestRateForBorrowingPerSecond = interestRateForBorrowing.div(OneYearAsSecond);
        uint interestRateForBorrowingPerBlock = interestRateForBorrowingPerSecond.mul(15);  // [Note]: 1 block == 15 seconds
        uint interestAmountForBorrowing = _wbtcAmountBorrowed.mul(interestRateForBorrowingPerBlock).div(100).mul(currentBlock.sub(_startBlock));

        uint repaymentAmount = _wbtcAmountBorrowed.add(interestAmountForBorrowing);
        return repaymentAmount;
    }

}