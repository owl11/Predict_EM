// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import {DateTimeLib} from "@solady/src/utils/DateTimeLib.sol";

contract dateTimeWrapper {
    struct CycleData {
        uint256 openingPrice;
        uint256 ClosingPrice;
        uint256 openingTimestamp;
        uint256 closingTimestamp;
    }

    mapping(uint16 _id => CycleData) public IDToData;
    // uint256 public pickingTime;

    function openingDate(uint16 _id)
        internal
        view
        returns (uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute, uint256 second)
    {
        (year, month, day, hour, minute, second) = DateTimeLib.timestampToDateTime(IDToData[_id].openingTimestamp);
        return (year, month, day, hour, minute, second);
    }

    function closingDate(uint16 _id)
        internal
        view
        returns (uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute, uint256 second)
    {
        (year, month, day, hour, minute, second) = DateTimeLib.timestampToDateTime(IDToData[_id].openingTimestamp);
        return (year, month, day, hour, minute, second);
    }

    function timestampToDate(uint256 _timestamp)
        public
        pure
        returns (uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute, uint256 second)
    {
        (year, month, day, hour, minute, second) = DateTimeLib.timestampToDateTime(_timestamp);
        return (year, month, day, hour, minute, second);
    }

    function dateFromId(uint16 _ID)
        public
        view
        returns (uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute, uint256 second)
    {
        CycleData memory data = IDToData[_ID];
        uint256 timestamp = data.openingTimestamp;
        (year, month, day, hour, minute, second) = DateTimeLib.timestampToDateTime(timestamp);
        return (year, month, day, hour, minute, second);
    }

    function isClosed(uint16 _id) public view returns (bool) {
        CycleData memory data = IDToData[_id];
        if (data.closingTimestamp == 0 || data.closingTimestamp > block.timestamp) {
            return false;
        }
        return (data.closingTimestamp < block.timestamp && data.openingTimestamp < block.timestamp);
    }

    function isOpen(uint16 _id) public view returns (bool) {
        CycleData memory data = IDToData[_id];
        if (data.openingTimestamp == 0) {
            return false;
        }
        return (data.openingTimestamp < block.timestamp && data.closingTimestamp > block.timestamp);
    }
    // function dateToTimesamp(
    //     uint256 year,
    //     uint256 month,
    //     uint256 day,
    //     uint256 hour,
    //     uint256 minute,
    //     uint256 second
    // ) public pure returns (uint256 result) {
    //     result = DateTimeLib.dateTimeToTimestamp(year, month, day, hour, minute, second);
    // }
}
