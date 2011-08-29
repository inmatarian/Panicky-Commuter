FILES = cgafont.png \
        CHIRP.wav \
        conf.lua \
        DEATH.wav \
        game.s3m \
        main.lua \
        tileset.png \
        title.s3m

love:
	zip PanickyCommuter.love $(FILES)

