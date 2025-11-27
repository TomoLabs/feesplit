// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract FeeSplitter {
    address[] public recipients;
    uint256[] public shares; // basis points (10000 = 100%)

    event FeeDistributed(address token, uint256 totalAmount);

    constructor(address[] memory _recipients, uint256[] memory _shares) {
        require(_recipients.length == _shares.length, "length mismatch");

        uint256 total;
        for (uint256 i; i < _shares.length; i++) {
            total += _shares[i];
        }
        require(total == 10000, "shares must equal 100%");


        recipients = _recipients;
        shares = _shares;
    }

    function distribute(address token, uint256 amount) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 payout = (amount * shares[i]) / 10000;

            (bool ok, ) = token.call(
                abi.encodeWithSignature("transfer(address,uint256)", recipients[i], payout)
            );
            require(ok, "transfer failed");
        }

        emit FeeDistributed(token, amount);
    }
}
