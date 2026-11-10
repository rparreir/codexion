#!/bin/bash
# Testes automáticos do codexion. Correr com: make test
# Começou com 100 testes; vão-se juntando os de cada tick (fases 4 e 5).
# Cada teste escreve PASS (verde), FAIL (vermelho) ou SKIP (amarelo, quando falta
# uma ferramenta). No fim aparece o resumo; o script sai com 1 se houver falhas.
# Os testes da secção 9 (margens de 10 ms sem burnout) podem falhar às vezes até à
# fase 5: sem ordem justa (fifo/edf), quem espreita primeiro ganha.

cd "$(dirname "$0")" || exit 1
BIN=./codexion
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

N=0
PASS=0
FAIL=0
SKIP=0
GREEN=$'\033[1;32m'
RED=$'\033[1;31m'
YELLOW=$'\033[1;33m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

pass()
{
	N=$((N + 1)); PASS=$((PASS + 1))
	printf "%4d  %sPASS%s  %s\n" "$N" "$GREEN" "$RESET" "$1"
}
fail()
{
	N=$((N + 1)); FAIL=$((FAIL + 1))
	printf "%4d  %sFAIL%s  %s\n" "$N" "$RED" "$RESET" "$1"
	[ -n "${2:-}" ] && printf "            %s↳ %s%s\n" "$RED" "$2" "$RESET"
}
skip()
{
	N=$((N + 1)); SKIP=$((SKIP + 1))
	printf "%4d  %sSKIP%s  %s\n" "$N" "$YELLOW" "$RESET" "$1"
	[ -n "${2:-}" ] && printf "            ↳ %s\n" "$2"
}
section() { printf "\n%s%s%s\n" "$BOLD" "$1" "$RESET"; }
note() { printf "            %s\n" "$1"; }

# corre o programa e guarda o stdout, o stderr e o código de saída
run() { timeout 15 "$BIN" "$@" >"$TMP/out" 2>"$TMP/err"; CODE=$?; }

# erro de argumentos: sai com 1, mensagem no stderr, nada no stdout
expect_error()
{
	local name=$1
	shift
	run "$@"
	if [ "$CODE" -eq 1 ] && [ ! -s "$TMP/out" ] && [ -s "$TMP/err" ]; then
		pass "$name"
	else
		fail "$name" "esperado: saída 1 e erro no stderr · obtido: saída $CODE, $(wc -l <"$TMP/out") linhas no stdout"
	fi
}

# termina logo: sai com 0 e não escreve nada
expect_silent()
{
	local name=$1
	shift
	run "$@"
	if [ "$CODE" -eq 0 ] && [ ! -s "$TMP/out" ] && [ ! -s "$TMP/err" ]; then
		pass "$name"
	else
		fail "$name" "esperado: saída 0 sem output · obtido: saída $CODE, $(wc -l <"$TMP/out") linhas"
	fi
}

# um só "burned out", na última linha, entre b e b + 10 ms
expect_burnout()
{
	local name=$1 b=$2 last nb t
	shift 2
	run "$@"
	last=$(tail -n 1 "$TMP/out")
	nb=$(grep -c 'burned out$' "$TMP/out")
	t=$(echo "$last" | awk '{ print $1 }')
	if [ "$CODE" -eq 0 ] && [ "$nb" -eq 1 ] && [[ "$last" == *"burned out" ]] \
		&& [[ "$t" =~ ^[0-9]+$ ]] && [ "$t" -ge "$b" ] && [ "$t" -le $((b + 10)) ]; then
		pass "$name → burned out aos $t ms"
	else
		fail "$name" "esperado: um só burned out, na última linha, entre $b e $((b + 10)) ms · obtido: saída $CODE, $nb burned out, última linha \"$last\""
	fi
}

# acaba por compilações: saída 0, nenhum burnout, cada coder compilou o pedido
expect_survive()
{
	local name=$1 short bo
	shift
	run "$@"
	short=$(awk -v n="$1" -v req="$6" '/is compiling$/ { c[$2]++ }
		END { for (i = 1; i <= n; i++) if (c[i] < req) { print "o coder " i " só compilou " c[i] + 0 " vezes"; exit } }' "$TMP/out")
	bo=$(grep -m 1 'burned out$' "$TMP/out")
	if [ "$CODE" -eq 0 ] && [ -z "$bo" ] && [ -z "$short" ]; then
		pass "$name"
	else
		fail "$name" "saída $CODE${bo:+ · \"$bo\"}${short:+ · $short}"
	fi
}

# ---------------------------------------------------------------------------
section "0. Compilação"
if make -s >"$TMP/make" 2>&1 && [ -x "$BIN" ]; then
	pass "compila com -Wall -Wextra -Werror"
else
	fail "compila com -Wall -Wextra -Werror" "$(head -n 3 "$TMP/make")"
	printf "\n%sSem executável, os outros testes não podem correr.%s\n" "$RED" "$RESET"
	exit 1
fi

# ---------------------------------------------------------------------------
section "1. Número de argumentos errado"
expect_error "sem argumentos"
expect_error "1 argumento" 3
expect_error "7 argumentos" 3 800 200 200 200 3 10
expect_error "9 argumentos" 3 800 200 200 200 3 10 fifo extra
expect_error "10 argumentos" 3 800 200 200 200 3 10 fifo extra extra

section "2. Cada número, com letras, negativo e acima do INT_MAX"
names=(number_of_coders time_to_burnout time_to_compile time_to_debug time_to_refactor number_of_compiles_required dongle_cooldown)
base=(3 800 200 200 200 3 10 fifo)
for pos in 0 1 2 3 4 5 6; do
	for bad in abc -5 2147483648; do
		args=("${base[@]}")
		args[pos]=$bad
		expect_error "${names[pos]} = $bad" "${args[@]}"
	done
done

section "3. Formatos traiçoeiros (no time_to_burnout)"
bads=("" "+5" " 5" "5 " "1.5" "5a" "0x1F" "1e3" "99999999999999999999" "4294967297")
notes=("vazio: o atoi dava 0" "sinal +" "espaço antes" "espaço depois" "decimal" \
	"o atoi dava 5" "hexadecimal" "notação científica" "20 dígitos: rebentava um long" \
	"o atoi dava a volta para 1")
for i in "${!bads[@]}"; do
	args=("${base[@]}")
	args[1]=${bads[i]}
	expect_error "\"${bads[i]}\" (${notes[i]})" "${args[@]}"
done

section "4. Zero coders, escrito de várias maneiras"
expect_error "number_of_coders = 0" 0 800 200 200 200 3 10 fifo
expect_error "number_of_coders = 00" 00 800 200 200 200 3 10 fifo
expect_error "number_of_coders = 0000000000" 0000000000 800 200 200 200 3 10 fifo

section "5. Scheduler inválido"
for bad in FIFO EDF fif fifoo "" " fifo" "fifo "; do
	expect_error "scheduler = \"$bad\"" 3 800 200 200 200 3 10 "$bad"
done

# ---------------------------------------------------------------------------
section "6. Valores-limite aceites (com 0 compilações, acaba sem output)"
zero=(3 800 200 200 200 0 10 fifo)
for pos in 1 2 3 4 6; do
	args=("${zero[@]}")
	args[pos]=2147483647
	expect_silent "${names[pos]} = INT_MAX é aceite" "${args[@]}"
done
expect_silent "number_of_coders = INT_MAX com 0 compilações (não pode fazer malloc)" 2147483647 800 200 200 200 0 10 fifo
expect_silent "zeros à esquerda (0800, 010) são aceites" 3 0800 0200 0200 0200 000 010 fifo
expect_silent "edf é aceite" 3 800 200 200 200 0 10 edf

section "7. Acaba antes de começar"
expect_silent "0 compilações com 200 coders → nada" 200 800 200 200 200 0 10 fifo
for n in 1 200 2147483647; do
	run "$n" 0 200 200 200 3 10 fifo
	if [ "$CODE" -eq 0 ] && [ "$(cat "$TMP/out")" = "0 1 burned out" ]; then
		pass "burnout 0 com N = $n → só \"0 1 burned out\""
	else
		fail "burnout 0 com N = $n → só \"0 1 burned out\"" "saída $CODE, output: \"$(head -c 80 "$TMP/out")\""
	fi
done
expect_silent "burnout 0 e 0 compilações → ganham as compilações (nada)" 3 0 200 200 200 0 10 fifo

# ---------------------------------------------------------------------------
section "8. Tem de dar burnout, a tempo (entre B e B + 10 ms)"
expect_burnout "1 coder, ciclo 400 > burnout 300" 300 1 300 100 100 200 5 0 fifo
# Era um teste "sem burnout" da fase 3. Com 1 coder há 1 dongle: o coder nunca
# compila, e o subject pede burnout, mesmo com o ciclo (600) abaixo do prazo (610).
expect_burnout "1 coder: um só dongle, nunca compila (ciclo 600 < burnout 610)" 610 1 610 200 200 200 3 0 fifo
expect_burnout "2 coders, ciclo 500 > 410" 410 2 410 200 200 100 5 0 fifo
expect_burnout "compile (200) maior que o burnout (100)" 100 3 100 200 100 100 3 0 fifo
expect_burnout "clássico: 4 310 200 100 100" 310 4 310 200 100 100 5 0 fifo
expect_burnout "margem de 10 ms: ciclo 600, burnout 590" 590 5 590 200 200 200 5 0 fifo
expect_burnout "o prazo conta desde o INÍCIO do compile (2 300 200 100 50)" 300 2 300 200 100 50 3 0 fifo
expect_burnout "burnout de 1 ms" 1 3 1 200 200 200 3 0 fifo
expect_burnout "burnout de 10 ms" 10 4 10 100 100 100 3 0 fifo
expect_burnout "tempos grandes: compile 1100 > burnout 1000" 1000 2 1000 1100 100 100 3 0 fifo
expect_burnout "200 coders, compile 400 > burnout 300" 300 200 300 400 100 100 3 0 fifo
expect_burnout "200 coders a escrever logs na hora do burnout" 100 200 100 50 50 50 5 0 fifo
expect_burnout "edf: 3 500 100 450 50" 500 3 500 100 450 50 3 0 edf
expect_burnout "com cooldown: 1 300 100 100 200, cooldown 50" 300 1 300 100 100 200 5 50 fifo
expect_burnout "compilações = INT_MAX (só pára por burnout)" 300 3 300 200 200 200 2147483647 0 fifo

section "9. Margens apertadas, sem burnout (só garantidas na fase 5, com fifo/edf)"
expect_survive "clássico: 4 410 200 100 100" 4 410 200 100 100 5 0 fifo
expect_survive "5 coders: 5 800 200 200 200" 5 800 200 200 200 3 0 fifo
expect_survive "200 coders com margem de 10 ms" 200 610 200 200 200 3 0 fifo
expect_survive "tempos todos a 0 (2 800 0 0 0 20)" 2 800 0 0 0 20 0 fifo
expect_survive "edf com margem de 10 ms" 3 610 200 200 200 3 0 edf

# ---------------------------------------------------------------------------
section "10. Comportamento difícil de ver a olho"
note "(200 coders com tempos 0: muitas threads a escrever ao mesmo tempo)"
run 200 800 0 0 0 30 0 fifo
bad=$(grep -v -E '^[0-9]+ [0-9]+ (has taken a dongle|is compiling|is debugging|is refactoring|burned out)$' "$TMP/out" | head -n 1)
[ -z "$bad" ] && bad=$(awk '$2 < 1 || $2 > 200 { print; exit }' "$TMP/out")
if [ "$CODE" -eq 0 ] && [ -z "$bad" ]; then
	pass "linhas nunca se misturam ($(wc -l <"$TMP/out") linhas, todas bem formadas)"
else
	fail "linhas nunca se misturam" "saída $CODE · linha errada: \"$bad\""
fi
bad=$(awk 'NR > 1 && $1 < prev { print NR ": " $0; exit } { prev = $1 }' "$TMP/out")
if [ -z "$bad" ]; then
	pass "timestamps nunca andam para trás, mesmo com 200 threads"
else
	fail "timestamps nunca andam para trás, mesmo com 200 threads" "linha $bad"
fi

run 3 800 120 80 60 4 0 fifo
bad=$(awk '$NF == "dongle" || $NF == "out" { next }
	{ want = (p[$2] == "") ? "compiling" : nx[p[$2]] }
	want != $NF { print "coder " $2 ": esperava \"is " want "\", veio \"" $0 "\""; exit }
	{ p[$2] = $NF }
	BEGIN { nx["compiling"] = "debugging"; nx["debugging"] = "refactoring"; nx["refactoring"] = "compiling" }' "$TMP/out")
if [ -z "$bad" ]; then
	pass "cada coder segue a ordem compiling → debugging → refactoring → compiling"
else
	fail "cada coder segue a ordem compiling → debugging → refactoring → compiling" "$bad"
fi
dev=$(awk '/is compiling$/ { c[$2] = $1 } /is debugging$/ && ($2 in c) { d = $1 - c[$2] - 120; if (d < 0) d = -d; if (d > m) m = d }
	END { print m + 0 }' "$TMP/out")
if [ "$dev" -le 2 ]; then pass "compile dura 120 ms (desvio máximo: $dev ms)"; else fail "compile dura 120 ms" "desvio máximo: $dev ms"; fi
dev=$(awk '/is debugging$/ { g[$2] = $1 } /is refactoring$/ && ($2 in g) { d = $1 - g[$2] - 80; if (d < 0) d = -d; if (d > m) m = d }
	END { print m + 0 }' "$TMP/out")
if [ "$dev" -le 2 ]; then pass "debug dura 80 ms (desvio máximo: $dev ms)"; else fail "debug dura 80 ms" "desvio máximo: $dev ms"; fi
low=$(awk '/is refactoring$/ { r[$2] = $1 } /is compiling$/ && ($2 in r) { d = $1 - r[$2]; if (min == "" || d < min) min = d }
	END { print (min == "") ? 999 : min }' "$TMP/out")
if [ "$low" -ge 59 ]; then
	pass "refactor dura pelo menos 60 ms até ao compile seguinte (mínimo: $low ms)"
else
	fail "refactor dura pelo menos 60 ms até ao compile seguinte" "mínimo: $low ms"
fi

run 7 800 100 100 100 2 0 fifo
miss=$(awk '{ s[$2] = 1 } END { for (i = 1; i <= 7; i++) if (!(i in s)) { print i; exit } }' "$TMP/out")
if [ -z "$miss" ]; then pass "todos os 7 coders aparecem nos logs"; else fail "todos os 7 coders aparecem nos logs" "o coder $miss nunca escreveu nada"; fi

# ---------------------------------------------------------------------------
section "11. Pendentes da fase 3 e repetições (os erros que só aparecem às vezes)"
# O subject não fixa a hora do arranque. Este teste guarda a porta de partida
# (decisão 9 da fase 3): sem ela, os coders arrancavam 2–20 ms atrasados.
# Com dongles, só alguns coders começam logo (os outros esperam pelos vizinhos),
# por isso vê-se só a 1.ª linha da simulação. Aceita o ms 1: se o tiro cair no fim
# de um ms, um coder que acorde 0,1 ms depois já está no ms seguinte (o relógio
# corta os µs).
run 5 800 200 200 200 1 0 fifo
first_ms=$(awk 'NR == 1 { print $1 }' "$TMP/out")
if [[ "$first_ms" =~ ^[0-9]+$ ]] && [ "$first_ms" -le 1 ]; then
	pass "arranque: a 1.ª linha da simulação sai no ms 0 ou 1 (saiu no ms $first_ms)"
else
	fail "arranque: a 1.ª linha da simulação sai no ms 0 ou 1" "saiu no ms ${first_ms:-?}"
fi

run 2 100000 200 200 200 5 0 fifo
dev=$(awk '/is compiling$/ { c[$2] = $1 } /is debugging$/ { d = $1 - c[$2] - 200; g[$2] = $1; chk(d) }
	/is refactoring$/ { d = $1 - g[$2] - 200; chk(d) }
	function chk(x) { if (x < 0) x = -x; if (x > m) m = x; n++ }
	END { print m + 0 " " n + 0 }' "$TMP/out")
if [ "${dev#* }" -gt 0 ] && [ "${dev% *}" -le 2 ]; then
	pass "precise_sleep: esperas de 200 ms com desvio ≤ 2 ms (maior: ${dev% *} ms em ${dev#* } esperas)"
else
	fail "precise_sleep: esperas de 200 ms com desvio ≤ 2 ms" "maior desvio: ${dev% *} ms em ${dev#* } esperas"
fi

note "(20 corridas com 200 coders, cerca de 1 min...)"
burned=0
hung=0
first=""
for i in $(seq 1 20); do
	timeout 15 "$BIN" 200 800 200 200 200 3 10 fifo >"$TMP/rep" 2>/dev/null
	[ $? -eq 124 ] && hung=$((hung + 1))
	if grep -q 'burned out$' "$TMP/rep"; then
		burned=$((burned + 1))
		[ -z "$first" ] && first="1.ª (corrida $i): \"$(grep -m 1 'burned out$' "$TMP/rep")\""
	fi
done
if [ "$hung" -eq 0 ]; then pass "200 coders × 20: nunca pendura"; else fail "200 coders × 20: nunca pendura" "pendurou em $hung de 20"; fi
if [ "$burned" -eq 0 ]; then pass "200 coders × 20: nenhum burnout falso"; else fail "200 coders × 20: nenhum burnout falso" "burnout em $burned de 20 corridas · $first"; fi

wrong=0
first=""
for i in $(seq 1 20); do
	timeout 15 "$BIN" 4 310 200 100 100 5 0 fifo >"$TMP/rep" 2>/dev/null
	nb=$(grep -c 'burned out$' "$TMP/rep")
	t=$(tail -n 1 "$TMP/rep" | awk '/burned out$/ { print $1 }')
	if [ "$nb" -ne 1 ] || [ -z "$t" ] || [ "$t" -lt 310 ] || [ "$t" -gt 320 ]; then
		wrong=$((wrong + 1))
		[ -z "$first" ] && first="1.ª errada (corrida $i): $nb burned out, última linha \"$(tail -n 1 "$TMP/rep")\""
	fi
done
if [ "$wrong" -eq 0 ]; then
	pass "burnout × 20 (4 310 200 100 100): sempre um só, na última linha, entre 310 e 320 ms"
else
	fail "burnout × 20 (4 310 200 100 100): sempre um só, na última linha, entre 310 e 320 ms" "errado em $wrong de 20 corridas · $first"
fi

# ---------------------------------------------------------------------------
section "12. Casos encontrados pelos colegas"
run 1 1000 100 100 100 5 1 edf
first=$(head -n 1 "$TMP/out")
last=$(tail -n 1 "$TMP/out")
t=$(echo "$last" | awk '/ 1 burned out$/ { print $1 }')
# aceita o "has taken" no ms 0 ou 1, pela mesma razão do teste do arranque (secção 11)
if [ "$CODE" -eq 0 ] && [ "$(wc -l <"$TMP/out")" -eq 2 ] \
	&& { [ "$first" = "0 1 has taken a dongle" ] || [ "$first" = "1 1 has taken a dongle" ]; } \
	&& [ -n "$t" ] && [ "$t" -ge 1000 ] && [ "$t" -le 1010 ]; then
	pass "1 1000 100 100 100 5 1 edf: 1 coder pega no único dongle e faz burnout aos $t ms"
else
	fail "1 1000 100 100 100 5 1 edf: só \"has taken a dongle\" (ms 0 ou 1) e burnout entre 1000 e 1010 ms" \
		"saída $CODE, $(wc -l <"$TMP/out") linhas, 1.ª \"$first\", última \"$last\""
fi
# um dos dois tem de esperar pelo cooldown (até aos 2 ms), e o seu prazo acaba ao 1 ms
expect_burnout "2 1 1 1 1 1 1 edf: um só burnout, quase imediato (passa depois do f4-t3)" 1 2 1 1 1 1 1 1 edf
# o cooldown aperta: o último compile começa aos 600 e o prazo é 650 (folga de 50 ms)
expect_survive "4 450 100 100 100 2 100 edf: o cooldown aperta, mas há folga → sem burnout" 4 450 100 100 100 2 100 edf

# ---------------------------------------------------------------------------
section "13. ThreadSanitizer (data races e inversões de mutex)"
if cc -Wall -Wextra -Werror -pthread -fsanitize=thread -g ./*.c -o "$TMP/codexion_tsan" 2>"$TMP/tsan_build"; then
	PREFIX=""
	command -v setarch >/dev/null && PREFIX="setarch $(uname -m) -R"
	for args in "2 800 100 300 500 2 10 fifo" "4 800 200 200 200 3 10 fifo" "20 800 200 200 200 2 10 edf"; do
		# shellcheck disable=SC2086
		timeout 60 $PREFIX "$TMP/codexion_tsan" $args >/dev/null 2>"$TMP/tsan"
		if grep -q 'FATAL: ThreadSanitizer' "$TMP/tsan"; then
			skip "TSan com $args" "o TSan não arranca neste sistema: $(grep -m 1 FATAL "$TMP/tsan")"
		elif grep -q 'WARNING: ThreadSanitizer' "$TMP/tsan"; then
			fail "TSan com $args" "$(grep -m 1 'WARNING: ThreadSanitizer' "$TMP/tsan")"
		else
			pass "TSan limpo com $args"
		fi
	done
else
	for i in 1 2 3; do skip "ThreadSanitizer" "não compilou com -fsanitize=thread"; done
fi

section "14. Valgrind (leaks e erros de memória)"
for args in "3 800 200 200 200 2 10 fifo" "2 800 100 300 500 2 10 fifo" "3 800 200 200 200 0 10 fifo" "3 0 200 200 200 3 10 fifo" "3 80a 200 200 200 3 10 fifo"; do
	if command -v valgrind >/dev/null; then
		# shellcheck disable=SC2086
		timeout 120 valgrind --leak-check=full --errors-for-leak-kinds=definite,indirect,possible \
			--error-exitcode=42 "$BIN" $args >/dev/null 2>"$TMP/vg"
		c=$?
		if [ "$c" -ne 42 ] && [ "$c" -ne 124 ] && grep -q 'ERROR SUMMARY: 0 errors' "$TMP/vg"; then
			pass "valgrind limpo com $args"
		else
			fail "valgrind com $args" "$(grep -m 1 -E 'definitely lost|ERROR SUMMARY' "$TMP/vg")"
		fi
	else
		skip "valgrind com $args" "o valgrind não está instalado"
	fi
done

section "15. Dongles (fase 4)"
note "(6 casos, 3 corridas cada, cerca de 1 min...)"
# Os dois testes leem os mesmos logs.
# - dois dongles: cada "is compiling" de um coder vem depois de exatamente dois
#   "has taken a dongle" desse coder, desde o compile anterior.
# - vizinhos: o compile de um coder vai do seu "is compiling" até + time_to_compile.
#   Dois vizinhos (i e i + 1, e o último com o 1.º) não se podem sobrepor. Uma
#   sobreposição até 2 ms é arredondamento dos ms; uma a sério dura um compile.
# - ordem do log: a regra do visualizador dos colegas
#   (codexion-visualizer.sacha-dev.me). Um coder segura os dongles desde cada
#   "has taken a dongle" até ao seu "is debugging". Lendo o log por ordem, um coder
#   não pode apanhar um dongle que o vizinho ainda segura (vizinho com 2).
bad_two=""
bad_nb=""
bad_lo=""
for args in "2 800 100 100 100 5 0 fifo" "3 800 200 200 200 5 0 fifo" \
	"4 410 200 100 100 5 0 fifo" "5 800 200 200 200 5 0 fifo" \
	"8 800 150 200 125 8 0 fifo" "200 800 200 200 200 3 0 fifo"; do
	n=${args%% *}
	c=$(echo "$args" | cut -d ' ' -f 3)
	for k in 1 2 3; do
		# shellcheck disable=SC2086
		timeout 15 "$BIN" $args >"$TMP/dg" 2>/dev/null
		if [ -z "$bad_two" ]; then
			r=$(awk '
				$3 == "has" { t[$2]++
					if (t[$2] > 2) { print "linha " NR ": o coder " $2 " apanhou 3 dongles sem compilar"; exit } }
				$3 == "is" && $4 == "compiling" {
					if (t[$2] != 2) { print "linha " NR ": o coder " $2 " compilou com " t[$2] + 0 " dongle(s)"; exit }
					t[$2] = 0 }' "$TMP/dg")
			[ -n "$r" ] && bad_two="$args · $r"
		fi
		if [ -z "$bad_nb" ]; then
			r=$(awk -v n="$n" -v c="$c" '
				$3 == "is" && $4 == "compiling" { s[$2, ++cnt[$2]] = $1 }
				END {
					for (i = 1; i <= n; i++) {
						j = i % n + 1
						if (j == i) continue
						for (a = 1; a <= cnt[i]; a++) for (b = 1; b <= cnt[j]; b++) {
							lo = s[i, a] > s[j, b] ? s[i, a] : s[j, b]
							hi = s[i, a] < s[j, b] ? s[i, a] + c : s[j, b] + c
							if (hi - lo > 2) {
								printf "os coders %d e %d compilaram ao mesmo tempo (desde os %d e os %d ms)\n", i, j, s[i, a], s[j, b]
								exit
							}
						}
					}
				}' "$TMP/dg")
			[ -n "$r" ] && bad_nb="$args · $r"
		fi
		if [ -z "$bad_lo" ]; then
			r=$(awk -v n="$n" '
				$3 == "has" {
					x = $2; h[x]++
					l = (x == 1) ? n : x - 1; r = (x == n) ? 1 : x + 1
					if (n == 2) bad = (h[x] + h[l] > 2)
					else bad = (h[l] == 2 && h[r] == 2) || (h[x] == 2 && (h[l] == 2 || h[r] == 2))
					if (bad) {
						printf "linha %d: \"%s\", com o coder %d a segurar %d e o coder %d a segurar %d\n", NR, $0, l, h[l], r, h[r]
						exit
					}
				}
				$3 == "is" && $4 == "debugging" { h[$2] = 0 }' "$TMP/dg")
			[ -n "$r" ] && bad_lo="$args · $r"
		fi
	done
done
if [ -z "$bad_two" ]; then pass "antes de cada \"is compiling\", dois \"has taken a dongle\" desse coder"; else fail "antes de cada \"is compiling\", dois \"has taken a dongle\" desse coder" "$bad_two"; fi
if [ -z "$bad_nb" ]; then pass "dois vizinhos nunca compilam ao mesmo tempo"; else fail "dois vizinhos nunca compilam ao mesmo tempo" "$bad_nb"; fi
if [ -z "$bad_lo" ]; then pass "na ordem do log, ninguém apanha um dongle antes de o vizinho escrever \"is debugging\""; else fail "na ordem do log, ninguém apanha um dongle antes de o vizinho escrever \"is debugging\"" "$bad_lo"; fi

# Cópia que escreve também o número do dongle ("has taken dongle 3"), para as
# secções 16 e 17. O programa a sério não muda.
mkdir -p "$TMP/volta"
cp ./*.c ./*.h "$TMP/volta/"
sed -i 's/print_status(coder, "has taken a dongle");/{ char m[32]; snprintf(m, sizeof(m), "has taken dongle %d", dongle->id); print_status(coder, m); }/' "$TMP/volta/dongle.c"
IDS=""
if grep -q 'has taken dongle %d' "$TMP/volta/dongle.c" \
	&& cc -pthread "$TMP"/volta/*.c -o "$TMP/volta/cx" 2>/dev/null; then
	IDS="$TMP/volta/cx"
fi

section "16. Cooldown (fase 4)"
# Regra do subject: depois de largado, um dongle fica dongle_cooldown ms sem poder
# ser apanhado. "Largado" = a linha "is debugging" de quem o tinha (é também a regra
# do visualizador dos colegas). Com 2 coders, os dois começam pelo mesmo dongle, por
# isso quem perde só apanha alguma coisa depois de o outro largar.
cool_gap()
{
	timeout 15 "$BIN" "$@" >"$TMP/cd" 2>/dev/null
	awk '$3 == "is" && $4 == "debugging" && a == "" { a = $2; r = $1 }
		$3 == "has" && a != "" && $2 != a { print $1 - r; exit }' "$TMP/cd"
}
g=$(cool_gap 2 1000 100 100 100 3 50 fifo)
if [[ "$g" =~ ^[0-9]+$ ]] && [ "$g" -ge 50 ] && [ "$g" -le 60 ]; then
	pass "cooldown 50: o vizinho apanha o dongle 50 a 60 ms depois de largado ($g ms)"
else
	fail "cooldown 50: o vizinho apanha o dongle 50 a 60 ms depois de largado" "passaram ${g:-?} ms"
fi
g=$(cool_gap 2 1000 100 100 100 3 0 fifo)
if [[ "$g" =~ ^[0-9]+$ ]] && [ "$g" -le 10 ]; then
	pass "cooldown 0: o vizinho apanha o dongle logo ($g ms)"
else
	fail "cooldown 0: o vizinho apanha o dongle logo" "passaram ${g:-?} ms"
fi
# o dongle só volta aos 600, mas os prazos acabam aos 300
expect_burnout "cooldown 500 maior que a folga: 2 300 100 100 100 3 500" 300 2 300 100 100 100 3 500 fifo
if [ -n "$IDS" ]; then
	bad_cd=""
	for args in "9 547 212 79 136 4 41 edf" "4 1000 100 100 100 5 400 edf" \
		"5 800 200 100 100 5 50 fifo" "200 1000 100 100 100 3 10 edf"; do
		cd_ms=$(echo "$args" | cut -d ' ' -f 7)
		for k in 1 2 3; do
			[ -n "$bad_cd" ] && break
			# shellcheck disable=SC2086
			timeout 15 "$IDS" $args >"$TMP/cd" 2>/dev/null
			r=$(awk -v cd="$cd_ms" '
				$3 == "has" && $5 == "dongle" {
					if (($6 in rel) && $1 < rel[$6] + cd) {
						printf "linha %d: o coder %d apanhou o D%d aos %d ms; foi largado aos %d, só podia aos %d\n", NR, $2, $6, $1, rel[$6], rel[$6] + cd
						exit
					}
					held[$2] = held[$2] " " $6
				}
				$3 == "is" && $4 == "debugging" {
					k = split(held[$2], a, " ")
					for (i = 1; i <= k; i++) rel[a[i]] = $1
					held[$2] = ""
				}' "$TMP/cd")
			[ -n "$r" ] && bad_cd="$args · $r"
		done
	done
	if [ -z "$bad_cd" ]; then pass "nenhum dongle é apanhado antes de largado + cooldown (4 casos × 3)"; else fail "nenhum dongle é apanhado antes de largado + cooldown" "$bad_cd"; fi
else
	skip "nenhum dongle é apanhado antes de largado + cooldown" "não deu para fazer a cópia com o número do dongle"
fi

section "17. Primeira volta: que dongles apanha cada coder (só para ver, não conta)"
# Usa a cópia com o número do dongle. Prazo de 2000 ms para todos chegarem ao 1.º
# compile. O resultado muda de corrida para corrida: quem espreita primeiro ganha.
args="5 2000 200 200 200 1 0 fifo"
if [ -n "$IDS" ]; then
	# shellcheck disable=SC2086
	timeout 15 "$IDS" $args >"$TMP/volta/out" 2>/dev/null
	note "$args"
	note ""
	awk -v n="${args%% *}" '
		$3 == "has" && $5 == "dongle" && cnt[$2] < 2 {
			cnt[$2]++; d[$2, cnt[$2]] = $6; t[$2, cnt[$2]] = $1
		}
		$3 == "is" && $4 == "compiling" && !($2 in c) { c[$2] = $1 }
		END {
			for (i = 1; i <= n; i++) {
				line = sprintf("C%-3d", i)
				if (cnt[i] >= 1) line = line sprintf("1.º D%-2s aos %4d ms", d[i, 1], t[i, 1])
				if (cnt[i] >= 2) line = line sprintf("  ·  2.º D%-2s aos %4d ms", d[i, 2], t[i, 2])
				if (i in c) line = line sprintf("  →  compila aos %4d ms", c[i])
				else line = line "  →  não chegou a compilar"
				if (cnt[i] >= 2 && t[i, 2] - t[i, 1] > 1)
					line = line sprintf("   (segurou o D%s %d ms à espera do D%s)", d[i, 1], t[i, 2] - t[i, 1], d[i, 2])
				print line
			}
		}' "$TMP/volta/out" | while IFS= read -r line; do note "$line"; done
else
	note "não deu para fazer a cópia: o log \"has taken a dongle\" do dongle.c mudou?"
fi

# ---------------------------------------------------------------------------
printf "\n%s==========================================================%s\n" "$BOLD" "$RESET"
if [ "$FAIL" -eq 0 ]; then
	printf "  %sTUDO CERTO%s   %d testes: %d PASS · %d FAIL · %d SKIP\n" "$GREEN" "$RESET" "$N" "$PASS" "$FAIL" "$SKIP"
else
	printf "  %sHÁ FALHAS%s    %d testes: %d PASS · %s%d FAIL%s · %d SKIP\n" "$RED" "$RESET" "$N" "$PASS" "$RED" "$FAIL" "$RESET" "$SKIP"
fi
printf "%s==========================================================%s\n" "$BOLD" "$RESET"
[ "$FAIL" -eq 0 ]
