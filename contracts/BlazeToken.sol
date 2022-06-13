// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract BlazeToken is ERC20, Ownable {

    event BlazeTokensMinted(address indexed to, uint256 indexed amount);
    constructor() ERC20("BlazeToken", "BLZ") {}

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
        emit BlazeTokensMinted(_to, _amount);
    }
}
