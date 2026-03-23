document.addEventListener('DOMContentLoaded', () => {
    const channelListContainer = document.getElementById('channel-list');
    const searchInput = document.getElementById('search-input');
    const videoElement = document.getElementById('video-player');
    const channelNameDisplay = document.getElementById('channel-name-display');
    const channelStatus = document.getElementById('channel-status');

    // Login Elements
    const loginOverlay = document.getElementById('login-overlay');
    const loginForm = document.getElementById('login-form');
    const accessCodeInput = document.getElementById('access-code');
    const loginError = document.getElementById('login-error');
    const CORRECT_CODE = "lvs"; // Hardcoded access code

    // Check Login Status
    if (localStorage.getItem('isLoggedIn') === 'true') {
        loginOverlay.classList.add('hidden');
    }

    // Handle Login
    loginForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const enteredCode = accessCodeInput.value.trim();

        if (enteredCode === CORRECT_CODE) {
            localStorage.setItem('isLoggedIn', 'true');
            loginOverlay.classList.add('hidden');
            loginError.textContent = '';
        } else {
            loginError.textContent = 'Incorrect access code. Please try again.';
            loginOverlay.classList.remove('hidden');
            accessCodeInput.value = '';
            accessCodeInput.focus();
        }
    });

    let hls;

    // Render Channel List
    function renderChannels(channelsToRender) {
        channelListContainer.innerHTML = '';
        channelsToRender.forEach(channel => {
            const channelItem = document.createElement('div');
            channelItem.className = 'channel-item';
            channelItem.onclick = () => playChannel(channel, channelItem);

            channelItem.innerHTML = `
                <img src="${channel.icon}" alt="${channel.name}" class="channel-icon" onerror="this.src='https://via.placeholder.com/48?text=TV'">
                <div class="channel-info-list">
                    <div class="channel-name">${channel.name}</div>
                    <div class="channel-category">${channel.category}</div>
                </div>
            `;
            channelListContainer.appendChild(channelItem);
        });
    }

    // Initial render
    renderChannels(channels);

    // Filter functionality
    searchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.toLowerCase();
        const filteredChannels = channels.filter(channel =>
            channel.name.toLowerCase().includes(searchTerm) ||
            channel.category.toLowerCase().includes(searchTerm)
        );
        renderChannels(filteredChannels);
    });

    // Play Channel
    function playChannel(channel, element) {
        // Update Active State
        document.querySelectorAll('.channel-item').forEach(item => item.classList.remove('active'));
        if (element) element.classList.add('active');

        // Update Info
        channelNameDisplay.textContent = channel.name;

        if (!channel.url) {
            channelStatus.textContent = "No Stream Source Available";
            channelStatus.style.color = "#ef4444"; // Red for error
            videoElement.pause();
            return;
        }

        channelStatus.textContent = "Live";
        channelStatus.style.color = "#6366f1"; // Accent color

        // Check if running in Flutter implementation
        if (typeof PlayChannel !== 'undefined') {
            PlayChannel.postMessage(JSON.stringify({
                url: channel.url,
                name: channel.name,
                category: channel.category
            }));
            // We can pause the local video element just in case
            videoElement.pause();
            return;
        }

        if (Hls.isSupported()) {
            if (hls) {
                hls.destroy();
            }
            hls = new Hls();
            hls.loadSource(channel.url);
            hls.attachMedia(videoElement);
            hls.on(Hls.Events.MANIFEST_PARSED, function () {
                videoElement.play();
            });
            hls.on(Hls.Events.ERROR, function (event, data) {
                console.error("HLS Error:", data);
                if (data.fatal) {
                    channelStatus.textContent = "Stream Error";
                    channelStatus.style.color = "#ef4444";
                }
            });
        }
        else if (videoElement.canPlayType('application/vnd.apple.mpegurl')) {
            videoElement.src = channel.url;
            videoElement.addEventListener('loadedmetadata', function () {
                videoElement.play();
            });
        }
    }


    // Keyboard and interaction controls
    videoElement.addEventListener('dblclick', toggleFullscreen);

    function toggleFullscreen() {
        if (!document.fullscreenElement) {
            if (videoElement.requestFullscreen) {
                videoElement.requestFullscreen();
            } else if (videoElement.webkitRequestFullscreen) { /* Safari */
                videoElement.webkitRequestFullscreen();
            } else if (videoElement.msRequestFullscreen) { /* IE11 */
                videoElement.msRequestFullscreen();
            }
        } else {
            if (document.exitFullscreen) {
                document.exitFullscreen();
            } else if (document.webkitExitFullscreen) { /* Safari */
                document.webkitExitFullscreen();
            } else if (document.msExitFullscreen) { /* IE11 */
                document.msExitFullscreen();
            }
        }
    }

    document.addEventListener('keydown', (e) => {
        // Ignore if user is typing in a search box or input
        if (document.activeElement.tagName === 'INPUT' ||
            document.activeElement.tagName === 'TEXTAREA' ||
            document.activeElement.isContentEditable) {
            return;
        }

        switch (e.code) {
            case 'Space':
                e.preventDefault(); // Prevent scrolling
                if (videoElement.paused) {
                    videoElement.play();
                } else {
                    videoElement.pause();
                }
                break;

            case 'KeyF':
                toggleFullscreen();
                break;

            case 'KeyM':
                videoElement.muted = !videoElement.muted;
                break;

            case 'ArrowUp':
                if (e.ctrlKey) {
                    e.preventDefault();
                    videoElement.volume = Math.min(1, videoElement.volume + 0.1);
                }
                break;

            case 'ArrowDown':
                if (e.ctrlKey) {
                    e.preventDefault();
                    videoElement.volume = Math.max(0, videoElement.volume - 0.1);
                }
                break;
        }
    });
});
