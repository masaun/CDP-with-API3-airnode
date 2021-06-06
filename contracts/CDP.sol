//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { DAI } from "./mock-tokens/DAI.sol";
import { WBTC } from "./mock-tokens/WBTC.sol";

// API3
import { ExampleClient } from "./ExampleClient.sol";


contract CDP {

    uint borrowLimitRate = 50;  // 50 (%)

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
    }

    /**
     * @notice - A user can borrow WBTC until 50% of collateralized-DAI amount
     * @notice - BTC price is retrieved via API3 oracle
     * @param btcPrice - BTC/USD price that is retrieved via API3 oracle. (eg. bitcoin price is 35548 USD)
     */
    function borrowWBTC(uint btcPrice, uint borrowWBTCAmount) public returns (bool) {
        // [Todo]:
    }

    function repayWBTC() public returns (bool) {}

    function withdrawDAI() public returns (bool) {}

}