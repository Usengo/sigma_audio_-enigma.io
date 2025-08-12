const { IPFS } = require('ipfs-core');

async function storeMetadataOnIPFS(metadata) {
    const ipfs = await IPFS.create();
    const { cid } = await ipfs.add(JSON.stringify(metadata));
    return `ipfs://${cid.toString()}`;
}