function night_mode_toggle
    set target_process "gammastep"
    
    if pgrep $target_process > /dev/null
        killall -s SIGINT .gammastep-wrap
    else
        # BUG: geopositioning doesn't work, which is why I set the lat:lon here.
        gammastep -l 33.6424:-117.8417 # UCI lat:long coords     
    end
end
