//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { WBTC } from "./WBTC.sol";

// API3
import { ExampleClient } from "./ExampleClient.sol";


contract CDP {

    WBTC public wbtc;

    constructor(WBTC _wbtc) public {
        wbtc = _wbtc;
    }

    /**
     * @notice - Using Wrapped BTC (WBTC)
     */
    function lendWBTC() public returns (bool) {}

    function borrowDAI() public returns (bool) {}

    function repayDAI() public returns (bool) {}

    function withdrawWBTC() public returns (bool) {}

}