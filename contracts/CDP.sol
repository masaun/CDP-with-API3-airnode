//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

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

    struct Lend {  // Also collateral
        uint daiAmountLended;
    }
    
    struct Borrow {
        uint wbtcAmountBorrowed;
    }

    mapping(address => mapping(uint => Lend)) lends;  // User address -> Lend ID 
    mapping(address => mapping(uint => Borrow)) borrows;  // User address -> Borrow ID 

    // Rate
    uint interestRateForLending = 5;     // 5 (%)  <- Calculated every block
    uint interestRateForBorrowing = 10;  // 10 (%) <- Calculated every block
    uint borrowLimitRate = 50;           // 50 (%) of collateral asset amount

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
        uint borrowLimit = daiAmountLended.mul(btcPrice).div(1e18).mul(borrowLimitRate).div(100);
        require(borrowWBTCAmount <= borrowLimit, "WBTC amount borrowing must be less that the limit amount borrowing");

        wbtc.transfer(borrower, borrowWBTCAmount);

        _borrow(borrowWBTCAmount);
    }

    function repayWBTC(uint borrowId) public returns (bool) {
        address borrower = msg.sender;
        Borrow memory borrow = borrows[borrower][borrowId];
        uint wbtcAmountBorrowed = borrow.wbtcAmountBorrowed;

        // [Todo]: Calculate interests amount of borrowing by every block
        uint interestAmountForBorrowing;

        // [Todo]: Calculate a repayment amount
        uint repayAmount;  
    }

    function withdrawDAI() public returns (bool) {
        // [Todo]: Calculate earned-interests amount of lending by every block
        uint interestAmountForLending;
    }


    //------------------
    // Internal methods
    //------------------
    function _lend(uint daiAmountLended) public returns (bool) {
        currentLendId++;
        Lend storage lend = lends[msg.sender][currentLendId];
        lend.daiAmountLended = daiAmountLended;
    }

    function _borrow(uint wbtcAmountBorrowed) public returns (bool) {
        currentBorrowId++;
        Borrow storage borrow = borrows[msg.sender][currentBorrowId];
        borrow.wbtcAmountBorrowed = wbtcAmountBorrowed;
    }  

}