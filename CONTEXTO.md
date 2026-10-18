# CONTEXTO: Copiloto Auto

App Flutter (Android primeiro) que conecta a um adaptador ELM327 (Bluetooth clássico/SPP) e mostra a saúde do carro: temperatura do motor, consumo, velocidade e erros da ECU. Nota geral de 0 a 100%.

Nome do pacote Flutter: `copilotoauto` (sem underscore). Nome de exibição: Copiloto Auto.

## Usuário
- Iniciante em Flutter. Explicar em poucas frases o papel de cada arquivo e dar passos curtos.
- Windows com PowerShell. Nunca usar sintaxe Bash nos comandos.
- Português do Brasil. Nomes de exibição em português e fáceis de falar. Evitar "cacar".
- Carro de teste: Honda Fit 2008 LX. O app é genérico para carros OBD2.
- Flutter 3.47.7 (stable).

## Ambiente
- Projeto rodando no emulador Android. Bluetooth real exige celular físico.
- `android/app/build.gradle.kts`: `ndkVersion = "30.0.16248370"`. Não reverter para `flutter.ndkVersion`.
- `android/gradle.properties`: contém `kotlin.incremental=false` e `kotlin.compiler.execution.strategy=in-process`. NÃO remover. Sem isso, o build falha com erro de cache do Kotlin quando o pub cache (C:) e o projeto (G:) estão em drives diferentes.
- `AndroidManifest.xml`: as `<uses-permission>` ficam diretamente dentro de `<manifest>`, nunca dentro de `<application>` (quebra o AAPT). Permissões atuais: BLUETOOTH e BLUETOOTH_ADMIN (maxSdk 30), BLUETOOTH_SCAN, BLUETOOTH_CONNECT e ACCESS_FINE_LOCATION.
- Bluetooth clássico: pacote `flutter_classic_bluetooth` (versão 1.7.0), instalado e com build validado. Exige Flutter 3.44 ou superior.
- `flutter_bluetooth_serial` foi removido (usa `jcenter()`, incompatível com o Gradle atual).
- `permission_handler` foi removido (exige compileSdk 37; o projeto usa 36). O próprio `flutter_classic_bluetooth` tem helper de permissões, então não é necessário.
- Antes de adicionar qualquer pacote novo, verificar no pub.dev: data da última atualização, suporte Android e issues recentes de Gradle/AGP.
- Aviso "restricted method in java.lang.System" do Gradle é ruído, não erro.

## Metodologia de testes
- Testes funcionais: cada teste verifica um comportamento que o usuário percebe ou depende. Ex.: "motor a 85 °C dá nota 100%" ou "NO DATA devolve null sem travar o app".
- Os testes da camada OBD usam `FakeTransport`, então rodam sem carro.
- Antes de cada entrega: `flutter analyze` sem avisos e `flutter test` com tudo passando.
- Lógica nova de saúde, consumo ou protocolo: escrever o teste junto com o código.
- Telas são validadas manualmente no emulador ou celular.
- Estado atual: testes em `test/obd_test.dart` (8, decodificadores e protocolo), `test/health_score_test.dart` e `test/telemetry_store_test.dart`. Rodar `flutter test` para confirmar que todos passam.

## Regras de negócio (ficam no core, não na tela)
- Motor: 100 até 98 °C; acima disso perde 4 pontos por grau. Temperatura baixa não penaliza a nota.
- Eletrônica: cada erro da ECU tira 20 pontos. Sem leitura de DTC (`dtcCount` nulo), a eletrônica fica sem nota (null), e não é tratada como 100%.
- Geral: média das duas notas. Se a eletrônica não tiver nota, a geral usa só o motor.
- Sem temperatura, não há relatório (`buildHealthReport` devolve null) e a tela mostra `--`.
- Cor da nota: `healthColor()` faz transição de vermelho (0%) a laranja (40%), amarelo (70%) e verde água (100%).
- Consumo instantâneo: a partir do MAF (14,7:1, densidade 745 g/L). Nulo se carro parado ou sem MAF.
- Consumo médio: integra distância e combustível entre leituras com intervalo até 10 s. Intervalos maiores são descartados.
- "Ao vivo": offline se passar 6 s sem leitura.

## Visual aprovado
- Tema claro: cartão de saúde branco, como os outros cartões. Medidor e arco na cor da nota. Chips em cinza claro.
- Tema escuro: cartão de saúde com gradiente azul-petróleo (`#164E63` a `#0C4A6E`).
- Bolinha "Ao vivo" pulsante no cabeçalho do cartão de saúde.
- Botão de lua/sol alterna o tema pelo `AppTheme.themeMode`. Botão de play/pause liga o simulador.

## Estrutura e responsabilidade de cada arquivo (`lib/`)
- `main.dart`: ponto de entrada. MaterialApp com tema claro e escuro, abre a DashboardPage.
- `core/app_theme.dart`: cores, `cardDecoration(context)` e `themeMode`.
- `core/health_score.dart`: `computeHealth()` (nota de motor e eletrônica), `buildHealthReport()` (regra completa, aceita nulos) e `healthColor()` (cor da nota). `SystemHealth.score` e `level` aceitam null.
- `core/telemetry.dart`: modelo de uma leitura (temperatura, velocidade, RPM, MAF, combustível e horário).
- `core/telemetry_bus.dart`: canal broadcast por onde a camada OBD publica leituras.
- `core/telemetry_store.dart`: escuta o bus e expõe valores para a tela (última leitura, ao vivo, consumo instantâneo e médio, `dtcCount`). Contém `fuelLitersPerHour` e `instantKmPerLiter`.
- `core/telemetry_simulator.dart`: gera leituras falsas no bus para testar a tela sem o carro. Será removido quando o PidPoller estiver ligado.
- `core/app_services.dart`: instâncias únicas de bus, store e simulador usadas pelo app.
- `obd/transport/obd_transport.dart`: contrato de transporte (`write`, `incoming`, `isConnected`). Permite mock nos testes.
- `obd/transport/spp_transport.dart`: implementação Bluetooth clássico com `flutter_classic_bluetooth`. Métodos: `pairedDevices()`, `connect(address)`, `write`, `disconnect`, `dispose`. Ainda não testado com o carro. Não trata permissões: a tela de pareamento pede antes.
- `obd/protocol/elm327.dart`: protocolo ELM327 (`init()` com ATZ, ATE0, ATL0, ATSP0; `query()` para PIDs). Testado.
- `obd/decoders/pid_decoders.dart`: fórmulas de temperatura, RPM, velocidade, MAF e combustível, e leitura de DTC. Testado.
- `obd/polling/pid_poller.dart`: a cada 2 s lê os sensores e publica no bus. Escrito, ainda não ligado.
- `data/db/app_database.dart`: placeholder para drift.
- `data/repositories/telemetry_repository.dart`: placeholder.
- `features/dashboard/dashboard_page.dart`: tela principal. Lê o `telemetryStore` e chama `buildHealthReport`. Não contém regra de negócio.
- `features/diagnostics/diagnostics_page.dart`: placeholder da tela de diagnóstico.

## Próximos passos
1. Confirmar pareamento do ELM327 no celular real (Configurações > Bluetooth).
2. Tela de pareamento: pedir permissão, listar pareados, destacar ELM327/OBDII, conectar, rodar `Elm327.init()` e mostrar "Conectado" ou o erro.
3. Ligar `PidPoller` ao `telemetryBus` no lugar do simulador, quando a conexão real funcionar.
4. Tela de diagnóstico: lista de DTCs (modo 03) e limpeza com confirmação (modo 04). Ao ler DTCs, chamar `setDtcCount`.
5. Persistência com drift (histórico e DTCs).

## Modelo de trabalho
- Código entregue como script PowerShell (here-string `@' ... '@ | Set-Content`). Para mudanças pequenas, dar o trecho exato a substituir.
- Sempre dizer o caminho exato do arquivo.
- Um passo por vez. Esperar confirmação antes de avançar.
- Ao final de cada etapa, perguntar se funcionou e qual é o próximo passo.
- Quando houver erro, pedir a saída completa ou o stack trace antes de chutar a causa.
- Não afirmar causa de erro sem evidência. Se for palpite, dizer que é palpite.
- Verificar pacotes no pub.dev (ou por busca) antes de recomendar.
- Respostas curtas, formatação mínima.
