async function fetchAndDisplayMetadata(tokenId) {
    const metadataURI = await contract.tokenURI(tokenId);
    const response = await fetch(metadataURI);
    const metadata = await response.json();

    console.log("Title:", metadata.title);
    console.log("Artist:", metadata.artist);
    console.log("Album:", metadata.album);
    console.log("Release Date:", metadata.releaseDate);
    console.log("Genre:", metadata.genre);
    console.log("Duration:", metadata.duration);
    console.log("Album Art:", metadata.albumArt);
    console.log("Audio File:", metadata.audioFile);
    console.log("Lyrics:", metadata.lyrics);
}