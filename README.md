<img width="966" alt="image" src="https://github.com/user-attachments/assets/6adba38a-0075-446e-a475-f56b477b7a6a" />


Flow of Operation:
1. User calls swapExactInput() on MostProfitableSwap
2. Contract queries all registered adapters for quotes
3. Selects adapter offering best output amount
4. Executes swap via chosen adapter
5. Returns swap results to user
