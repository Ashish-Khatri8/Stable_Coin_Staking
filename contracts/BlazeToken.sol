// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract BlazeToken is ERC20Upgradeable, OwnableUpgradeable {

    event BlazeTokensMinted(address indexed to, uint256 indexed amount);
    
    function initialize() public initializer {
        __Ownable_init();
        __ERC20_init("BlazeToken", "BLZ");
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
        emit BlazeTokensMinted(_to, _amount);
    }
}
