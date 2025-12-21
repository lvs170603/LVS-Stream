# Live TV Application

A premium, web-based Live TV streaming application.

## Features
- **Modern Dark Interface**: Designed with a sleek, glassmorphic UI.
- **HLS Streaming**: Built-in support for `.m3u8` streams using HLS.js.
- **Channel Search**: Quickly find channels by name or category.
- **Responsive Design**: Works on different screen sizes.

## How to use

1. **Add Stream URLs**:
   Open `channels.js` in a text editor. You will see a list of channels. Add your `.m3u8` stream links to the `url` field for each channel.
   
   Example:
   ```javascript
   {
       name: "ETV Telugu",
       icon: "Live Tv Icons/ETV Telugu.png",
       url: "https://example.com/stream/etv_telugu.m3u8", // <--- Add URL here
       category: "General"
   }
   ```

2. **Run the App**:
   Simply open `index.html` in your web browser. 
   
   *Note: live streams often have CORS policies. If streams don't play, you might need to disable CORS in your browser for testing or serve the app through a local server.*

## Troubleshooting
- **No Signal**: This means the URL for the channel is empty or invalid.
- **Stream Error**: The stream URL might be broken or offline.
