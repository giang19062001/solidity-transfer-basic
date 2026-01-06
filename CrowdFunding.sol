// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";


// msg.sender là địa chỉ người gọi contract này OR địa chỉ của 1 contract khác gọi tới contract này
// msg.value là giá trị Wei, ETH,.. khi gọi contract này --> chỉ hoạt động trong hàm đánh dấu là 'payable'

contract Crowdfunding {
    error NotOwner(); // khai báo lỗi để ném cho revert -> khuyên dùng -> tiết kiệm gas thay vì ném lỗi chuỗi 

    using PriceConverter for uint256; // khai báo sử dụng thư viện, chỉ Áp dụng library cho các kiểu dữ liệu uint256 khớp với tham số type của hàm trong library

    mapping(address => uint256) public addressToAmountFunded;
    address[] public funders;

    // immutable -> cũng như constant là không thể thay đổi, tuy nhiên có thể gán giá trị init cho nó bên trong 'constructor'
    address public immutable i_owner;

    // constant -> hằng số không thể thay đổi
    uint256 public constant MINIMUM_USD = 1e18; // 1 USD với đơn vị Wei (1000000000000000000)


    // Event là một cách để contract gửi thông báo đến bên ngoài blockchain (ví dụ: frontend, backend, hoặc các contract khác).
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


    // 'modifier' -> từ khóa này giúp tái sử dụng logic ở nhiều hàm khác nhau ( hàm withdraw() bên dưới tái sử dụng nội dung code của  onlyOwner() này)
    modifier onlyOwner() {
        // chỉ chủ sở hữu mới có thể rút tiền từ contract về ví của mình
        // 'revert' -> hoàn tác tác vụ và quăng lỗi
        // dung  revert error() thay vì revert('bạn ko phải chủ sở hữu') -> tiết kiệm gas -> khuyên dùng
        if (msg.sender != i_owner) revert NotOwner();
        // !!!  _ đặt kí hiệu này phía sau nội dung trong hàm được modifier 
        // -> đồng nghĩa là các hàm nào tái sử dụng hàm onlyOwner() sẽ chạy sau khi đoạn code trong onlyOwner() chạy xong
        // !!! _ đặt kí hiệu này phía trước nội dung trong hàm được modifier -> sẽ chạy đoạn code trong onlyOwner() này sau đoạn code gọi nó
        _;
    }

    // !!! Để 1 contract có thể NHẬN ETH, Wei,.. mà ko contract ko có tự viết hàm  'payable'  NHẬN -> bắt buộc phải có 2 hàm này: fallback(), receive()
    // !!! Nếu contract hiện tại Ko có chức năng NHẬN ETH, Wei,... -> ko cần khai báo 2 hàm này, cũng như không cần tự viết viết hàm 'payable' 

    // Gửi ETH,.. -> nếu msg.data (calldata) có -> fallback()
    fallback() external payable {
        fund();
    }
    // Gửi ETH,.. -> nếu msg.data (calldata) trống -> receive()
    receive() external payable {
        fund();
    }

    // !!! fallback() và receive() chỉ xử lý các transaction gửi ETH trực tiếp đến địa chỉ contract mà không cần thông qua gọi hàm 'payable' tự viết nào.
    // !!! fund() xử lý các transaction gửi ETH thông qua hàm 'payable' tự viết

    // payable chỉ cho biết rằng  hàm này có thể NHẬN giá trị Wei, ETH,...
    function fund() public payable {
        // 'require' kiểm tra điều kiện và ném lỗi sẽ thấy ở phần 'status' -> có thể check trên 'etherscan'

        // !!!! msg.value.getConversionRate() thay vì getConversionRate(msg.value) vì ta đang dùng library
        // ---> nó chỉ cho phép ~ giá trị có type uint256 gọi hàm của library đó
        // ---> nên phải viết như gọi 1 method như này, solidity tự khắc biết msg.value sẽ là tham số đầu tiên cho hàm getConversionRate() đó
        // @@@@@ require(msg.value.getConversionRate() >= MINIMUM_USD, "You need to spend more ETH!");  // so sánh giá thực tế lấy từ chainlink so sánh với giá điều kiện 
        addressToAmountFunded[msg.sender] += msg.value; // cộng đồn số tiền đã donate cho người donate hiện tại
        funders.push(msg.sender);
        emit Funded(msg.sender, msg.value); // gửi event ra ngoài on-chain ( kiểm tra phần logs )
    }

    // onlyOwner -> gọi đoạn code tái sử dụng
    function withdraw() public onlyOwner {
        // address(this).balance  ---> giá trị balancer mà địa chỉ contract hiện tại đang nắm giữ
        //  address(this) --->  trả ra địa chỉ của contract này
        uint256 balance = address(this).balance;

        // reset mapping của funder với số tiền họ từng donate về 0
        for (uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }

        funders = new address[](0); // reset mảng funders về rỗng sau khi rút hết tiền 

        // payable(msg.sender) để 1 địa chỉ có thể gọi các hàm chuyển tiền có sẵn cho chính địa chỉ đó
        // Các hàm có sẵn của payable(address) như: transfer, send, call
        (bool callSuccess,) = payable(msg.sender).call{value: balance}("");
        require(callSuccess, "Call failed");

        emit Withdrawn(msg.sender, balance); // gửi event ra ngoài on-chain ( kiểm tra phần logs )
    }
}