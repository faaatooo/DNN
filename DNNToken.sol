
// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

    contract DNNToken is ERC20{
        constructor() ERC20("DNNToken", "DNNTK")
        {
            _mint (msg.sender, 10000000);
        }
}