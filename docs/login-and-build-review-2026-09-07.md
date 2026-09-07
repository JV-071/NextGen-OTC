# Revisão de login e builds — 2026-09-07

## Login

O log do artefato 592ea71 revelou `invalid bestiary overview entry` após o
servidor aceitar o personagem. Não é a mensagem de rejeição de assinatura.
O servidor local envia em 0xD6 um byte antes do progresso e, quando progresso
é maior que zero, outro depois da ocorrência. O parser anterior não consumia
esses campos da versão 15.25+. A leitura seguinte ficava desalinhada.

5b25920 ajusta essa leitura, inicializa campos opcionais e usa a exceção que o
parser de protocolo já trata. O teste nativo cobre entradas bloqueadas/reveladas,
formatos anteriores, truncamento e alinhamento com o próximo opcode. A build
Windows executa esse teste antes de publicar o artefato. Ainda é necessário
confirmar a entrada e movimentação com o personagem na nova build.

## Configuração e distribuição

`config.ini` estava ausente do repositório. Agora há um arquivo padrão com os
mesmos valores internos do NextGen. Sua ausência usa os padrões e é informada
como configuração opcional; INI malformado continua sendo reportado como erro.
Não contém senha. As configurações do usuário continuam em `config.otml`.

O pacote `NextGen-OTC-windows-release` passa a ser uma atualização binária:
executável, PDB correspondente, ILK quando gerado e DLLs caso necessárias.
ILK serve ao linker, não é requisito para jogar. Não forçamos link incremental
apenas para produzi-lo. O PDB é útil para depurar e pode ser grande; o tamanho
comprimido final só pode ser confirmado após o upload.

Para instalar do zero, obter os dados/módulos da mesma revisão do NextGen e os
assets do servidor. Uma execução manual com `include_runtime=true` produz
`NextGen-OTC-runtime` separado, incluindo `config.ini`. Não substitua dados e
módulos pelos do OpenTibiaBR indiscriminadamente. Não copie o novo config sobre
personalizações sem comparar.

## Compilações

Na revisão 592ea71: Windows, Windows Server, Android e Linux passaram; macOS e
browser falharam. Linux publicou um artefato de 918594941 bytes. Passar na
compilação não comprova execução em Android/Linux nem entrada no jogo.

macOS falhou no link de `SecCertificateCopyData` e
`SecTrustSettingsCopyCertificates`; 5b25920 adiciona o framework Security.
Na execução 34152142504, macOS e Linux passaram com 5b25920 e publicaram
artefatos (917572645 e 918599793 bytes, respectivamente); execução gráfica e
login nessas plataformas ainda não foram validados.
Browser ainda referencia `browser/include/lua51/liblua.a`, que não existe.
Faltam a integração de compilação e a compatibilidade do interpretador com os
módulos que usam `goto`; não basta criar um arquivo vazio nem usar Lua 5.1 padrão.

Os novos workflows Linux, macOS e Browser têm entradas separadas, mas reutilizam
uma implementação comum. Mantêm os mesmos triplets, toolchains e nomes de cache.
O workflow comum também permite execução manual por plataforma ou de todas.

Cache Windows verificado na execução 34108213909: 45 dependências restauradas
em 13 segundos e cache sccache restaurado. Os 3 hits de compilador reportados não
significam que toda a build foi atendida pelo cache. Não foi alterado o cache de
dependências/compilador para reduzir o tamanho do pacote.

## Referências upstream

- https://github.com/opentibiabr/otclient/commit/0d59566842ff23d39ec9a09f50a28d541fddcf27
  corrige resolução de caminhos OTUI relativos dentro de callbacks, com testes.
  É útil para janelas abertas sob demanda e possivelmente para o editor; não é
  a causa da exceção do bestiário. Integração e testes no NextGen pendentes.
- https://github.com/opentibiabr/otclient/pull/1632 continua aberta. Melhora o
  atualizador (checagens, escopo de checksums e cache PHP), não o protocolo de
  login. O próprio autor pede testes Android. Não foi importada em bloco:
  envolve o serviço PHP e a escrita/remoção de arquivos do cliente. Requer
  testes de atualização interrompida, manifesto, escopo e preservação de assets.
- https://github.com/opentibiabr/otclient/blob/main/.github/workflows/reusable-build-windows.yml
  usa builds reutilizáveis e publica a pasta de binários, além de uma matriz de
  configurações MSBuild. Usa também cache NuGet/GitHub Packages. Não copiamos
  essa infraestrutura de credenciais nem ampliamos nossa matriz sem necessidade.

## Windows Server e DirectX

A build Windows comum já usa x64, runtime MSVC estático e a API Windows 10;
é destinada também a Windows Server moderno com interface gráfica e driver
OpenGL adequado. O runner `windows-2022` é Windows Server. Isso não garante
renderização por RDP, Server Core ou máquinas sem driver compatível.
A build Server separada usa Release, sem testes; não constitui um backend
gráfico diferente. Uma validação no servidor-alvo ainda é necessária.

Na interface atual, opções chamadas DirectX 12 e OpenGL acabam selecionando
`renderBackend=gl`; não foi encontrado um renderizador D3D12 nativo nesse
caminho. Mesa pode fornecer OpenGL sobre D3D12, mas isso depende do driver:
https://docs.mesa3d.org/drivers/d3d12.html

`TOGGLE_DIRECTX` procura bibliotecas do SDK antigo; não implementa por si só
DirectX 9. O caminho EGL de Windows pede contexto OpenGL ES 3, não ES 2.
Suporte DX9 real permanece pendente: precisa de um backend ou ponte
gráfica e testes de shaders, atlas, minimapa/HD e desempenho. Não anunciamos
compatibilidade apenas habilitando a opção de compilação. Referência possível:
https://chromium.googlesource.com/angle/angle/+/main

O trabalho de CPU deve partir de uma sessão funcional, com FPS/resolução/mapa
comparáveis. Não foram reduzidos qualidade, FPS ou recursos como solução para
o erro de protocolo.
