# foundry friday

been meaning to foundry pill myself, found a little energy after NFT NYC.

my main concern was that we are doing a lot of extra things around meta-transactions, signatures and custom errors to support our cross-chain token gating solution.

0xEssential offers a [client SDK](https://github.com/0xEssential/essential-signer) for our meta-tx solution that we also use in our [hardhat tests](https://github.com/0xEssential/PlaySession/blob/main/test/index.test.ts#L90).

Those tests end up being a bit more integrative - there's a lot of value in a more e2e test that covers our SDK and forwarding contract and context primitives in an implementation contract. But I'd heard good things about Foundry and wanted to give it a shot.

