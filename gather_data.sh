
# --- CONFIG -----

OUTPUT_FOLDER="outputs/$(date +'%Y_%m_%d_%H_%M_%S')"
NUM_ELEMS="5 40 100"
VARIANTS="python bash c"
SLEEP_SECONDS=60

# ----------------

for VARIANT in $VARIANTS; do
    if [[ $VARIANT == "c" ]]; then
        gcc -o "mem_test-c/main" "mem_test-c/main.c"
    fi

    docker build --tag "mem_test/$VARIANT" --file "mem_test-$VARIANT/Dockerfile" "mem_test-$VARIANT" > /dev/null
done

docker image prune --force > /dev/null
docker rm -f $(docker ps -f name=elem -q) > /dev/null 2>&1
mkdir -p "$OUTPUT_FOLDER"

for NUM_ELEM in $NUM_ELEMS; do
    for VARIANT in $VARIANTS; do
        printf "[%s] Running %s with %s elements\n" "$VARIANT" "$VARIANT" "$NUM_ELEM"

        # Docker
        printf "[%s] Spawning Docker containers\n" "$VARIANT"
        cat /proc/meminfo | awk '{print $2}' > "${OUTPUT_FOLDER}/${VARIANT}__${NUM_ELEM}__docker_before"

        for i in $(seq 1 $NUM_ELEM)
        do
            docker run --detach --rm --network host --name elem_$i "mem_test/$VARIANT" > /dev/null
        done

        sleep $SLEEP_SECONDS # Allow all containers to start
        printf "[%s] Spawned %s containers\n" "$VARIANT" "$(docker ps -q | wc -l)"
        cat /proc/meminfo | awk '{print $2}' > "${OUTPUT_FOLDER}/${VARIANT}__${NUM_ELEM}__docker_after"
        docker rm -f $(docker ps -a -q) > /dev/null
        printf "[%s] Remaining %s containers\n" "$VARIANT" "$(docker ps -q | wc -l)"

        sleep $SLEEP_SECONDS

        # Bash
        cat /proc/meminfo | awk '{print $2}' > "${OUTPUT_FOLDER}/${VARIANT}__${NUM_ELEM}__bash_before"

        printf "[%s] Spawning processes\n" "$VARIANT"
        for i in $(seq 1 $NUM_ELEM) 
        do
            if [[ $VARIANT == "scheduler" ]]; then
                CMD="source .venv/bin/activate && python -m gs_scheduler"
                EXP="python -m gs_scheduler"
            elif [[ $VARIANT == "python" ]]; then
                CMD="python main.py"
                EXP=$CMD
            elif [[ $VARIANT == "bash" ]]; then
                CMD="bash main.sh"
                EXP=$CMD
            elif [[ $VARIANT == "c" ]]; then
                CMD="./main"
                EXP="main"
            else
                exit -1
            fi
                
            nohup bash -c "cd mem_test-$VARIANT && $CMD" > /dev/null 2>&1 &
        done

        sleep $SLEEP_SECONDS #Allow all processes to spawn
        printf "[%s] Spawned %s processes\n" "$VARIANT" $(pgrep -f "$EXP" | wc -l)
        cat /proc/meminfo | awk '{print $2}' > "${OUTPUT_FOLDER}/${VARIANT}__${NUM_ELEM}__bash_after"
        pkill -f "$EXP"
        sleep 10
        printf "[%s] Reminaing %s processes\n" "$VARIANT" $(pgrep -f "$EXP" | wc -l)

        printf "\n------------------------------------------------\n\n"

    done
done
