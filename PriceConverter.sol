// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

//Chainlink chỉ hoạt động trên testnet hoặc mainnet, ko hoạt động local remix
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


// dùng 'library' giúp tái sử dụng code ở nhiều chỗ -> tiết kiễm gas
library PriceConverter {
    function getPrice() internal view returns (uint256) {
        // địa chỉ '0x694AA1769357215DE4FAC081bf1f309aDC325306' là là của cặp 'ETH / USD' trong price-feeds của chainlink oracle
        // địa chỉ này cho biết giá thực tế của 1 ETH là bao nhiêu USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        (
             /* uint80 roundId */,
            int256 answer,
            ,
            /*uint256 startedAt*/
            ,
            /*uint256 updatedAt*/
            /*uint80 answeredInRound*/
        ) =  priceFeed.latestRoundData(); // hàm trả về giá trị thực tể của USD của 1 đồng coin nào đó dựa vào địa chỉ  'feed price'
        require(answer > 0, "Invalid price data");
        // Vì chainlink luôn trả về 8 decimals
        // nhưng Solidity xài 18 decimals
        // decimal là những số đứng sau 4 số đầu ( số thực ) VD: 200000000000 là 2000.00 -> 00000000 (8 decimals)
        // thêm vào 10 số 0 để lấy thành 18 decimals VD: 200000000000 (8 decimals) là 2000.00 ->  2000000000000000000000  (18 decimals) là 2000.00
        return uint256(answer) * 1e10; // đơn vị theo Wei
    }

    function getConversionRate(
        uint256 ethAmount
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice();
        // chuẩn vẫn là 18 decimals, vì có 2 số 18 decimals nhân với nhau thì khả năng thành 36 decimals
        // nên chia cho 1e18 để lấy lại 18 decimals
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18; // đơn vị theo Wei
        return ethAmountInUsd;
    }
}
