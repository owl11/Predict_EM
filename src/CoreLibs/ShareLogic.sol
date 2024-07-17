// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

contract ShareLogic {
    mapping(uint8 => uint256) public totalSupply;
    mapping(address user => mapping(uint8 side => uint256 balance)) public balanceOf;

    event mint(address receiver, uint8 side, uint256 amount);
    event burn(address receiver, uint8 side, uint256 amount);
    event synced(
        uint256 amountsSynced_1,
        uint256 amountsSynced_2,
        uint256 excess,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 oldPrice1,
        uint256 oldPrice2,
        uint256 newPrice1,
        uint256 newPrice2
    );

    uint256 private amountCounter;

    function createMarket() internal returns (bool) {
        _mint(address(this), 1, 707000); //
        _mint(address(this), 2, 707000);
        //
        return true;
    }

    function totalSupplyMinusMM(uint8 _side) public view returns (uint256) {
        uint256 amtToSub = balanceOf[address(this)][_side];
        uint256 totSupply = totalSupply[_side];
        totSupply -= amtToSub; // we remove the contracts balance to get the existing supplies actual total
        return totSupply;
    }

    function getTotalSupply(uint8 _side) public view returns (uint256) {
        uint256 totSupply = totalSupply[_side];
        return totSupply;
    }

    function getbalanceOf(address _sender, uint8 _side) public view returns (uint256) {
        uint256 totSupply = balanceOf[_sender][_side];
        return totSupply;
    }

    function getPriceOut(uint256 supply, uint256 amount) internal pure returns (uint256) {
        // The pricing curve proof for this is as follows, but the curve follows supply^2/coefficient to determine the price
        // So the price equals Σp(i), where i is the supply and p(i) = i^2 / coefficient, up to supply + amount
        // Which equals Σp(i) to i=s from i=0 to s+a - Σp(i) to i=s from i=0
        // So we get Σi^2 / curveCoefficient to i=0 to s+a - Σi^2 / curveCoefficient to i=0 to s
        // Pull out the curveCoefficient and we get Σi^2 - Σi^2
        // Using the external proof Σi^2 from i=0 to i=n of n(n+1)(2n+1)/6
        // and we get the code below
        uint256 curveCoefficient = 100_000_000;

        uint256 sum1 = supply == 0 ? 0 : (supply - 1) * (supply) * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 && amount == 1
            ? 0
            : (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6;

        uint256 summation = sum2 - sum1;

        return (summation * 1 ether / curveCoefficient) / 10 ** 16;
    }

    function getPricePerSide(uint8 _side, uint256 shareamount) public view returns (uint256) {
        if (_side == 1) {
            uint256 supply = totalSupply[_side];
            return getPriceOut(supply, shareamount);
        } else if (_side == 2) {
            uint256 supply = totalSupply[_side];
            return getPriceOut(supply, shareamount);
        } else {
            revert();
        }
    }

    function _mint(address receiver, uint8 _side, uint256 amount) internal {
        balanceOf[receiver][_side] += amount;
        totalSupply[_side] += amount;
        emit mint(receiver, _side, amount);

        // emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(address sender, uint8 _side, uint256 amount) internal {
        balanceOf[sender][_side] -= amount;
        totalSupply[_side] -= amount;
        emit burn(sender, _side, amount);

        // emit Transfer(msg.sender, sender, address(0), id, amount);
    }

    function marketMake(uint8 _side, uint256 amount, uint8 ID) internal {
        if (_side == 1) {
            if (ID == 1) {
                _burn(address(this), 2, amount);
            } else {
                _mint(address(this), 2, amount);
            }
        }
        if (_side == 2) {
            if (ID == 1) {
                _burn(address(this), 1, amount);
            } else {
                _mint(address(this), 1, amount);
            }
        }
        sync_2();
    }

    function sync_2() public returns (uint256 amountsSynced_1, uint256 amountsSynced_2, uint256 excess) {
        uint256 price_1 = getPricePerSide(1, 1);
        uint256 price_2 = getPricePerSide(2, 1);
        uint256 totalPrice = price_1 + price_2;

        uint256 totalSupply_1 = getTotalSupply(1);
        uint256 totalSupply_2 = getTotalSupply(2);
        uint256 totalSupply_sum = totalSupply_1 + totalSupply_2;

        if (totalPrice > 1_005_000) {
            excess = totalPrice - 1_000_000;
            excess = excess / 2;

            amountsSynced_1 = (excess * totalSupply_1) / totalSupply_sum;
            amountsSynced_2 = (excess * totalSupply_2) / totalSupply_sum;

            // Burn the calculated amounts from both sides
            _burn(address(this), 1, amountsSynced_1);
            _burn(address(this), 2, amountsSynced_2);
        } else if (totalPrice < 998_500) {
            // Assuming the target price range is 0.997 to 1.003
            excess = 1_000_000 - totalPrice;
            excess = excess / 2;

            amountsSynced_1 = (excess * totalSupply_1) / totalSupply_sum;
            amountsSynced_2 = (excess * totalSupply_2) / totalSupply_sum;

            _mint(address(this), 1, amountsSynced_1);
            _mint(address(this), 2, amountsSynced_2);
        } else {
            return (0, 0, 0);
        }
        uint256 newPrice_1 = getPricePerSide(1, 1);
        uint256 newPrice_2 = getPricePerSide(2, 1);
        uint256 newPrice = newPrice_1 + newPrice_2;
        emit synced(
            amountsSynced_1, amountsSynced_2, excess, totalPrice, newPrice, price_1, price_2, newPrice_1, newPrice_2
        );
        return (amountsSynced_1, amountsSynced_2, excess);
    }

    // function excess() public {
    //     uint256 balance_1 = totalSupplyMinusMM(1);
    //     uint256 balance_2 = totalSupplyMinusMM(2);
    //     uint256 contractBalance_1 = getbalanceOf(address(this), 1);
    //     uint256 contractBalance_2 = getbalanceOf(address(this), 2);
    //     uint256 mmParity;

    //     uint256 parity;
    //     if (balance_1 > balance_2) {
    //         parity = balance_1 / balance_2;
    //         mmParity = contractBalance_1 / contractBalance_2;
    //     } else {
    //         parity = balance_2 / balance_1;
    //     }
    // }
    // uint256 parity = totalSupplyMinusMM(1) + totalSupplyMinusMM(2);
    // if (parity > mmParity) {
    //     parity = parity / mmParity;
    // }
}
