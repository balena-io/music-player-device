Http = require('http')
GS = require('grooveshark-streaming')
Player = require('./player')

class Playlist extends Array
	constructor: -> super()

	playing: null
	log: (args...) ->
		if @playing?
			@playing.log(args...)
		else
			console.log("No Song Playing: ", args...)

	getStream: (song, callback) -> # Searching for song_name on Grooveshark
		@log("Getting info.")
		GS.Tinysong.getSongInfo(song.name, song.artist, (err, info) => # Getting SongID
			if info is null # Not found
				@log("Not found.")
				callback(true, null)
				return
			@log("Got info", info)

			@log("Getting stream_url.")
			GS.Grooveshark.getStreamingUrl(info.SongID, (err, stream_url) =>
				@log("Got stream_url '#{stream_url}.'")
				callback(err, stream_url)
			)
		)

	skip: ->
		@log('Skipping')
		if @playing?
			@playing.end()

	play: ->
		console.log("Music.play(): Checking if playing now or no song in queue.")
		if @playing or @length is 0
			console.log("Music.play(): Playing now or no song in queue.")
			return
		console.log("Music.play(): Can play.")

		song = @shift() # Getting the next song_name
		@playing = new Player(song)
		@playing.on('end', =>
			@playing = null
			@play()
		)
		console.log("Music.play(): Got", song)

		@getStream(song, (err, stream_url) =>
			if err # Could not fetch stream_url
				@log("Error getting stream url.", err)
				@playing = null
				return

			request = Http.get(stream_url) # Getting stream data
			request.on('response', (song_stream) => # Downloading stream data
				@playing.buffer(song_stream)

				interval = setInterval(=>
					time_remaining = song.start_time - Date.now()
					if time_remaining < 0
						@log("Should be playing now.")
						clearInterval(interval)
					else
						@log("Waiting #{time_remaining / 1000}s to sync with all devices.")
				, 1000)

				# Use a setTimeout to idle until 500ms before the planned start time.
				setTimeout(=>
					# Busy wait to be as accurate as possible to the start time.
					while song.start_time - Date.now() > 0
						null
					@playing.play() # Playing music
				, (song.start_time - 500) - Date.now())
			)
		)

module.exports = Playlist
