//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { DAI } from "./mock-tokens/DAI.sol";
import { WBTC } from "./mock-tokens/WBTC.sol";

// API3
import { ExampleClient } from "./ExampleClient.sol";


contract CDP {
    using SafeMath for uint;

    uint currentLendId;
    uint currentBorrowId;

    struct Lend {  // Also collateral
        uint daiAmountLended;
    }
    mapping(address => mapping(uint => Lend)) lends;  // User address -> Lend ID 
    
    struct Borrow {
        uint wbtcAmountBorrowed;
    }
    mapping(address => mapping(uint => Borrow)) borrows;  // User address -> Borrow ID 


    uint borrowLimitRate = 50;  // 50 (%) of collateral asset amount

    DAI public dai;
    WBTC public wbtc;

    constructor(DAI _dai,WBTC _wbtc) public {
        dai = _dai;
        wbtc = _wbtc;
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
        Lend memory lend = lends[msg.sender][lendId];
        uint daiAmountLended = lend.daiAmountLended;

        address borrower = msg.sender;
        uint borrowLimit = daiAmountLended.mul(btcPrice).div(1e18).mul(borrowLimitRate).div(100);
        require(borrowWBTCAmount <= borrowLimit, "WBTC amount borrowing must be less that the limit amount borrowing");

        wbtc.transfer(borrower, borrowWBTCAmount);

        _borrow(borrowWBTCAmount);        
    }

    function repayWBTC() public returns (bool) {}

    function withdrawDAI() public returns (bool) {}


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