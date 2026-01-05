// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";


// msg.sender là địa chỉ người gọi contract này OR địa chỉ của 1 contract khác gọi tới contract này
// msg.value là giá trị Wei, ETH,.. khi gọi contract này --> chỉ hoạt động trong hàm đánh dấu là 'payable'

contract Crowdfunding {
    error NotOwner();

    using PriceConverter for uint256;

    mapping(address => uint256) public addressToAmountFunded;
    address[] public funders;

    // immutable -> cũng như constant là không thể thay đổi, tuy nhiên có thể gán giá trị init cho nó bên trong 'constructor'
    address public immutable i_owner;

    // constant -> hằng số không thể thay đổi
    uint256 public constant MINIMUM_USD = 1 * 10 ** 18; //  Solidity, các token thường sử dụng 18 số thập phân (ví dụ: 1 ETH = 1e18 wei)
    event Funded(address indexed funder, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);

    // constructor sẽ chỉ chạy khi contract được deloy
    // **Cách 1: gán chủ sở hữu là người deploy contract
    constructor() {
        i_owner = msg.sender; // lấy và set địa chỉ của người deploy contract này làm chủ sở hữu
    }
    // **Cách 2: gán chủ sở hữu là địa chỉ ví nào đó truyền vào contract
    // constructor(address own){
    //     i_owner = own
    // }

    modifier onlyOwner() {
        // chỉ chủ sở hữu mới có thể rút tiền từ contract về ví của mình
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    // !!! Để 1 contract có thể nhận ETH, Wei,.. bắt buộc phải có 2 hàm này: fallback(), receive()
    // !!! Nếu contract hiện tại chỉ là contract gửi ETH, Wei - Ko có chức năng nhận -> ko cần khai báo 2 hàm này
    // Gửi ETH,.. -> nếu msg.data (calldata) có -> fallback()
    fallback() external payable {
        fund();
    }
    // Gửi ETH,.. -> nếu msg.data (calldata) trống -> receive()
    receive() external payable {
        fund();
    }

    // payable chỉ thêm cho các hàm nào có GỬI/NHẬN giá trị Wei, ETH,...
    function fund() public payable {
        // 'require' kiểm tra điều kiện và ném lỗi sẽ thấy ở phần 'status' -> có thể check trên 'etherscan'
        require(msg.value.getConversionRate() >= MINIMUM_USD, "You need to spend more ETH!");
        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
        emit Funded(msg.sender, msg.value);
    }

    function withdraw() public onlyOwner {
        // address(this).balance  ---> giá trị balancer mà địa chỉ contract hiện tại đang nắm giữ
        uint256 balance = address(this).balance;
        for (uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }

        funders = new address[](0);

        // payable(msg.sender) để 1 địa chỉ có thể gọi các hàm chuyển tiền có sẵn 
        (bool callSuccess,) = payable(msg.sender).call{value: balance}("");
        require(callSuccess, "Call failed");

        emit Withdrawn(msg.sender, balance);
    }
}