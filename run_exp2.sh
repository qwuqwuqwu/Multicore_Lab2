#!/bin/bash

# Usage: ./run_exp2.sh <num_trials>
# Example: ./run_exp2.sh 5

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <num_trials>"
    exit 1
fi

TRIALS=$1
SIZE=1000
ITER_LIST=(10 20 30 40)
THREADS=(1 2 4 8)
BINARY="./heatdist"
CSV_FILE="exp2_results.csv"

if [ ! -f "$BINARY" ]; then
    echo "Error: $BINARY not found. Compile first with:"
    echo "  gcc -Wall -std=c99 -fopenmp -o heatdist heatdist.c -lm"
    exit 1
fi

# Build CSV header
HEADER="iterations,mode,threads,warmup_time"
for t in $(seq 1 $TRIALS); do
    HEADER="${HEADER},trial_${t}"
done
echo "$HEADER" > "$CSV_FILE"

# Helper: run heatdist once and extract the time
run_once() {
    local itr=$1
    local mode=$2   # 0=sequential, 1=parallel
    local nthreads=$3
    local output
    output=$("$BINARY" "$SIZE" "$itr" "$mode" "$nthreads" 2>/dev/null)
    echo "$output" | grep "Time taken" | awk '{print $NF}'
}

for ITR in "${ITER_LIST[@]}"; do
    echo "=== Iterations: $ITR (size fixed at ${SIZE}x${SIZE}) ==="

    # --- Sequential (mode=0) ---
    echo "  [SEQ] warmup..."
    WARMUP=$(run_once "$ITR" 0 1)
    echo "    warmup = ${WARMUP}s"

    SEQ_TIMES=()
    for t in $(seq 1 $TRIALS); do
        T=$(run_once "$ITR" 0 1)
        SEQ_TIMES+=("$T")
        echo "    trial $t = ${T}s"
    done

    # Write sequential row
    ROW="${ITR},sequential,1,${WARMUP}"
    for T in "${SEQ_TIMES[@]}"; do
        ROW="${ROW},${T}"
    done
    echo "$ROW" >> "$CSV_FILE"

    # Compute mean sequential time for speedup reference
    SEQ_SUM=0
    for T in "${SEQ_TIMES[@]}"; do
        SEQ_SUM=$(echo "$SEQ_SUM + $T" | bc -l)
    done
    SEQ_MEAN=$(echo "$SEQ_SUM / $TRIALS" | bc -l)
    echo "    seq mean = $(printf '%.6f' $SEQ_MEAN)s"

    # --- Parallel (mode=1) for each thread count ---
    for NTHREADS in "${THREADS[@]}"; do
        echo "  [PAR threads=$NTHREADS] warmup..."
        WARMUP=$(run_once "$ITR" 1 "$NTHREADS")
        echo "    warmup = ${WARMUP}s"

        PAR_TIMES=()
        for t in $(seq 1 $TRIALS); do
            T=$(run_once "$ITR" 1 "$NTHREADS")
            PAR_TIMES+=("$T")
            echo "    trial $t = ${T}s"
        done

        # Write parallel row
        ROW="${ITR},parallel,${NTHREADS},${WARMUP}"
        for T in "${PAR_TIMES[@]}"; do
            ROW="${ROW},${T}"
        done
        echo "$ROW" >> "$CSV_FILE"

        # Print mean and speedup
        PAR_SUM=0
        for T in "${PAR_TIMES[@]}"; do
            PAR_SUM=$(echo "$PAR_SUM + $T" | bc -l)
        done
        PAR_MEAN=$(echo "$PAR_SUM / $TRIALS" | bc -l)
        SPEEDUP=$(echo "$SEQ_MEAN / $PAR_MEAN" | bc -l)
        echo "    par mean = $(printf '%.6f' $PAR_MEAN)s  speedup vs seq = $(printf '%.4f' $SPEEDUP)x"
    done

    echo ""
done

echo "Results saved to $CSV_FILE"
