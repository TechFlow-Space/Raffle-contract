pragma solidity ^0.5.0;

import "./Obi.sol";

library ParamsDecoder {
    using Obi for Obi.Data;

    struct Params {
        uint64 size;
    }

    function decodeParams(bytes memory _data)
        internal
        pure
        returns (Params memory result)
    {
        Obi.Data memory data = Obi.from(_data);
        result.size = data.decodeU64();
    }
}

library ResultDecoder {
    using Obi for Obi.Data;

    struct Result {
        string random_bytes;
    }

    function decodeResult(bytes memory _data)
        internal
        pure
        returns (Result memory result)
    {
        Obi.Data memory data = Obi.from(_data);
        result.random_bytes = string(data.decodeBytes());
    }
}

