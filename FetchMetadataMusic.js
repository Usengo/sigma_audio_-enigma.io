async function fetchTrackMetadata(trackId) {
    const accessToken = await getAccessToken();

    const trackOptions = {
        method: 'get',
        url: `https://api.spotify.com/v1/tracks/${trackId}`,
        headers: {
            'Authorization': `Bearer ${accessToken}`
        }
    };

    const response = await axios(trackOptions);
    const metadata = {
        title: response.data.name,
        artist: response.data.artists[0].name,
        album: response.data.album.name,
        releaseDate: response.data.album.release_date,
        genre: response.data.album.genres[0],
        duration: response.data.duration_ms,
        albumArt: response.data.album.images[0].url,
        audioFile: response.data.preview_url,
        lyrics: null // Lyrics may require a separate API call
    };

    return metadata;
}