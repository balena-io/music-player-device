Http = require('http')
Lame = require('lame')
Speaker = require('speaker')
GS = require('grooveshark-streaming')

Music =
	queue: []
	now_playing: false

	getStream: (song, callback) -> # Searching for song_name on Grooveshark
		console.log("'#{song.name} - #{song.artist}': Getting SongID.")
		GS.Tinysong.getSongInfo(song.name, song.artist, (err, info) => # Second param for artist_name but it is not separated from song.name yet
			if info is null # Not found
				console.log("'#{song.name} - #{song.artist}': SongID not found.")
				callback(true, null)
				return
			console.log("'#{song.name} - #{song.artist}': Got SongID '#{info.SongID}'.")

			console.log("'#{song.name} - #{song.artist}': Getting stream_url.")
			GS.Grooveshark.getStreamingUrl(info.SongID, (err, stream_url) =>
				console.log("'#{song.name} - #{song.artist}': Got stream_url '#{stream_url}.'")
				callback(err, stream_url)
			)
		)

	play: ->
		console.log("Music.play(): Checking if playing now or no song in queue.")
		if @now_playing or @queue.length is 0
			console.log("Music.play(): Playing now or no song in queue.")
			return
		console.log("Music.play(): Can play.")

		@now_playing = true
		song = @queue.shift() # Getting the next song_name
		console.log("Music.play(): Got song.name '#{song.name}', song.artist '#{song.artist}' and song.start_time '#{song.start_time}'.")

		@getStream(song, (err, stream_url) =>
			if err # Could not fetch stream_url
				console.log("#{song.name} - #{song.artist}: Setting now_playing false.")
				@now_playing = false
				console.log("#{song.name} - #{song.artist}: Set now_playing false.")
				return

			request = Http.get(stream_url) # Getting stream data
			decoder = new Lame.Decoder()
			stream = null

			request.on('close', => # Stream data have been downloaded
				@now_playing = false
				console.log("'#{song.name} - #{song.artist}': Closing stream.")
				stream.end()
				console.log("'#{song.name} - #{song.artist}': Closed stream.")
				@play()
			)
			request.on('response', (stream_data) => # Downloading stream data
				console.log("'#{song.name} - #{song.artist}': Piping to decoder.")
				stream = stream_data.pipe(decoder)
				console.log("'#{song.name} - #{song.artist}': Piped to decoder.")

				stream.on('format', (format) =>
					wait = song.start_time - Date.now() # Milliseconds

					wait_interval = Math.round(wait / 1000)
					console.log(Date.now(), song.start_time, wait, wait_interval)
					setInterval(=>
						console.log("'#{song.name}': Waiting #{wait_interval}s to sync with all devices.")
						wait_interval -= 1
					, 1000)

					setTimeout(=>
						console.log("'#{song.name} - #{song.artist}': Piping to speaker.")
						stream.pipe(new Speaker(format)) # Playing music
						console.log("'#{song.name} - #{song.artist}': Piped to speaker.")
					, wait)
				)
			)
		)

module.exports = Music
