+-------------------------------------+
|           SwapSwap System           |
+-------------------------------------+

+-------------------------------+       +---------------------------+
|    MostProfitableSwap.sol     |<----->|   IMostProfitableSwap     |
|   (Main Contract)             |       |   (Interface)             |
+---------|---------------------+       +---------------------------+
          |
          | manages
          v
 +--------+---------+         +---------------------------+
 |  DEX Adapters    |<------->|       IDEXAdapter         |
 |  Registry        |         |       (Interface)         |
 +--------+---------+         +---------------------------+
          |
          | contains
          v
 +--------+--------------------+
 |                             |
 |                             |
+-------------+   +-----------+
|UniswapV3    |   |UniswapV2  |
|Adapter      |   |Adapter    |
+-------------+   +-----------+
      |                 |
      v                 v
+-------------+   +-----------+
|UniswapV3    |   |UniswapV2  |
|Protocol     |   |Protocol   |
+-------------+   +-----------+

Flow of Operation:
1. User calls swapExactInput() on MostProfitableSwap
2. Contract queries all registered adapters for quotes
3. Selects adapter offering best output amount
4. Executes swap via chosen adapter
5. Returns swap results to user
