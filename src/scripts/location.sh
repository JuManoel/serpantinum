resolve_location() {
    local existing
    existing="$(get_existing_location)"

    local source
    source="$(echo "$existing" | jq -r '.source // empty' 2>/dev/null)"

    if [[ "$source" == "manual" && "$FORCE_REFRESH" == "false" ]]; then
        echo "$existing"
        return
    fi

    if [[ "$FORCE_REFRESH" == "false" && -n "$existing" && "$existing" != "null" ]]; then
        local updated_at current_time diff
        updated_at=$(echo "$existing" | jq -r '.updated_at // 0')
        current_time=$(date +%s)
        diff=$((current_time - updated_at))
        log_debug "Found location in config. Age: $diff seconds."
        if [ $diff -lt 86400 ]; then
            log_debug "Config location is fresh. Returning existing data."
            echo "$existing"
            return
        fi
    fi

    log_debug "Fetching location details..."
    local raw_loc
    raw_loc="$(fetch_ip_location)"

    if [[ -n "$raw_loc" && "$raw_loc" != "null" ]]; then
        log_debug "Geolocation retrieved successfully."
        local now
        now=$(date +%s)
        local final_loc
        final_loc=$(echo "$raw_loc" | jq --argjson ts "$now" '. + {updated_at: $ts}')
        save_location "$final_loc"
        echo "$final_loc"
    elif [[ -n "$existing" && "$existing" != "null" ]]; then
        log_debug "All providers failed. Falling back to existing config location."
        echo "$existing"
    else
        log_debug "No location data or config available. Defaulting to fallback payload."
        local fallback
        fallback='{"latitude": 0.0, "longitude": 0.0, "city": "Unknown", "region": "Unknown", "country_name": "Unknown", "timezone": "UTC", "updated_at": 0}'
        save_location "$fallback"
        echo "$fallback"
    fi
}
