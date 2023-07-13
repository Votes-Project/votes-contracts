// set the deploy network here

const network = 'goerli';

console.log(`${network} will be used for contract locations.`);

const locations = {
  "WETH": {
    "goerli": "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
    "sepolia": "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
    "optimism": "0x4200000000000000000000000000000000000006"
  },
  "Votes": {
    "goerli": "0xA237b3cC022F70B45AFdbe62EdF9C12ac36932F8",
    "sepolia": "0x083b23dC187502D4f4DAc683F023D7d25E087728",
    "optimism": ""
  }
};

//export { locations as WETH };

const weth = locations.WETH[network];
const votes = locations.Votes[network];

export { weth, votes };
