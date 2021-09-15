docker run -d --rm --name mem_test_element mem_test/c > /dev/null
nohup bash -c "cd ./mem_test-c && ./main" > /dev/null 2>&1 &

sleep 2 

printf "%s\n\n" "$(ps aux | grep main)"

for pid in $(pgrep -f './main'); do
    printf "%s\n\n" "$(cat /proc/$pid/status)"
done

docker rm -f mem_test_element > /dev/null
pkill -f './main'
