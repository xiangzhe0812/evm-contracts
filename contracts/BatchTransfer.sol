// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BatchTransfer is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for ERC20Upgradeable;
    address public transferOperator;
    address public token;
    address private self;

    uint256 private ethBalance;

    event Received(address, uint256);

    receive() external payable {
        ethBalance += msg.value;
        emit Received(msg.sender, msg.value);
    }

    modifier onlyTransferOperator() {
        require(msg.sender == transferOperator);
        _;
    }

    function initialize() public initializer onlyOwner {
        __Ownable_init();
        __UUPSUpgradeable_init();
        transferOperator = msg.sender;
        self = address(this);
        emit NewOperator(msg.sender);
    }

    function batchTransferToken(
        address[] calldata _recipients,
        uint256[] calldata _value,
        address _token
    ) external onlyTransferOperator {
        require(
            _value.length == _recipients.length,
            "Value and recipient lists are not the same length"
        );
        require(_token != address(0), "Token is invalid");

        token = _token;
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(
                _recipients[i] != address(0),
                "Recipient address is invalid"
            );
            require(_recipients[i] != msg.sender, "Cannot send to self");
        }
        uint256 totalValue;

        for (uint256 i = 0; i < _value.length; i++) {
            totalValue += _value[i];
        }

        require(
            totalValue <= ERC20Upgradeable(token).balanceOf(self),
            "Insufficient balance"
        );
        for (uint256 i = 0; i < _recipients.length; i++) {
            ERC20Upgradeable(token).safeTransferFrom(
                self,
                _recipients[i],
                _value[i]
            );
        }
    }

    function batchTransfer(
        address payable[] calldata _recipients,
        uint256[] calldata _value
    ) external payable onlyTransferOperator {
        require(
            _value.length == _recipients.length,
            "Value and recipient lists are not the same length"
        );
        uint256 totalValue;
        for (uint256 i = 0; i < _value.length; i++) {
            totalValue += _value[i];
        }
        require(ethBalance >= totalValue, "Insufficient balance");

        for (uint256 i = 0; i < _recipients.length; i++) {
            require(
                _recipients[i] != address(0) && _recipients[i] != msg.sender,
                "Recipient address is invalid"
            );
            _transfer(_recipients[i], _value[i]);
        }
    }

    function _transfer(address payable _recipient, uint256 _value) internal {
        _recipient.transfer(_value);
        emit Transfer(address(this), _recipient, _value);
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Token address can not be 0");
        require(_token != token, "Token address is already set");
        token = _token;
    }

    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "setOperator: Operator cannot be 0");
        require(
            _operator != transferOperator,
            "setProperty: Operator cannot be the same"
        );
        transferOperator = _operator;
        emit NewOperator(_operator);
    }

    function withdrawEth() external onlyOwner {
        uint256 value = address(this).balance;
        require(value > 0, "Insufficient balance");
        payable(msg.sender).transfer(value);
    }

    function withdrawToken(address _token) external onlyOwner {
        require(_token != address(0), "Token address can not be 0");
        require(_token == token, "Token address is not set");
        uint256 value = ERC20Upgradeable(_token).balanceOf(address(this));
        require(value > 0, "Insufficient balance");
        ERC20Upgradeable(_token).safeTransferFrom(self, msg.sender, value);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    event NewOperator(address operator);
    event Transfer(address indexed from, address indexed to, uint256 value);
}
