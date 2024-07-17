// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract mockUSDC is ERC20 {
    constructor() ERC20("mockUSDC", "MUSDC") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
