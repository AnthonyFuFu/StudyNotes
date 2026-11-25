# 實戰：AI、OCR 與周邊整合

!!! abstract "本章重點"

    業務系統常常要整合外部能力：大型語言模型、圖片辨識、文字辨識、報表與加密。本章整理 holidayDessert 中 Azure OpenAI、Azure AI Vision、Tesseract OCR、PDF / Excel 產製與 Jasypt 的實作方式，並指出可以改進的地方。

!!! abstract "專案：holidayDessert"

    `OpenAIController` / `ChatGPTService`（Azure OpenAI 對話、圖片描述）、`OcrController` / `OcrService`（Tess4J 繁體中文 OCR）、`PdfController`（iTextPDF）、Apache POI / JExcelAPI 報表、`JasyptController`（設定檔加解密）、springdoc-openapi（Swagger UI）。

## 整合一覽

| 能力 | 技術 | 用途 |
|------|------|------|
| 對話生成 | **Azure OpenAI**（`azure-ai-openai`） | 客服回覆草稿、商品文案 |
| 圖片描述 | **Azure AI Vision**（`azure-ai-vision-imageanalysis`） | 上傳圖片後自動產生說明文字（Caption） |
| 文字辨識 | **Tess4J**（Tesseract OCR） | 從圖片擷取繁體中文文字 |
| 報表 | **iTextPDF**、**Apache POI** | 產生 PDF 單據、匯出 Excel |
| 設定加密 | **Jasypt** | 設定檔中的密碼以 `ENC(...)` 加密儲存 |
| API 文件 | **springdoc-openapi** | 自動產生 OpenAPI 規格與 Swagger UI |

## Azure OpenAI

``` java
public ApiReturnObject getChat(String prompt) {
    OpenAIClient client = new OpenAIClientBuilder()
            .credential(new AzureKeyCredential(azureOpenAIConfig.getKey()))
            .endpoint(azureOpenAIConfig.getEndpoint())
            .buildClient();

    List<ChatRequestMessage> chatMessages = new ArrayList<>();
    chatMessages.add(new ChatRequestSystemMessage(prompt));

    ChatCompletions chatCompletions = client.getChatCompletions(
            azureOpenAIConfig.getDeployment(), new ChatCompletionsOptions(chatMessages));

    String replyContent = chatCompletions.getChoices().get(0).getMessage().getContent();
    return ApiReturnObject.success("取得對話成功", replyContent);
}
```

| 概念 | 說明 |
|------|------|
| **Deployment** | Azure 上部署的模型名稱，請求時指定 |
| **System 訊息** | 設定模型的角色與規則（「你是甜點店客服，只回答與商品有關的問題」） |
| **User 訊息** | 使用者的輸入 |
| **Token** | 計費與長度限制的單位，中文約 1 \~ 2 個字一個 token |
| **Temperature** | 越低越穩定、越高越有創意；客服類用 0 \~ 0.3 |

!!! tip "可以改進的地方"

    1. **使用者輸入應該放在 User 訊息**：目前把 `prompt` 當成 System 訊息送出，等於讓使用者可以直接改寫模型的角色設定（**Prompt Injection**）。正確做法是固定的 System 訊息 + 使用者的 User 訊息。
    2. **Client 只建立一次**：`OpenAIClient` 是執行緒安全的，應該註冊成 Bean 重複使用，不要每次請求都 `buildClient()`。
    3. **設定逾時、重試與錯誤處理**：外部 API 可能很慢或被限流（429），要有逾時與降級回應，不能讓使用者一直等。
    4. **金鑰不寫在設定檔**：改用 Azure Managed Identity 或 Key Vault。

    ``` java
    @Bean
    OpenAIClient openAIClient(AzureOpenAIConfig cfg) {
        return new OpenAIClientBuilder()
                .credential(new AzureKeyCredential(cfg.getKey()))
                .endpoint(cfg.getEndpoint())
                .buildClient();
    }

    public String reply(String userInput) {
        List<ChatRequestMessage> messages = List.of(
                new ChatRequestSystemMessage("你是假日甜點的客服，只回答商品、訂單與活動相關問題，不確定時請客人聯絡真人客服。"),
                new ChatRequestUserMessage(userInput));
        ChatCompletionsOptions options = new ChatCompletionsOptions(messages)
                .setTemperature(0.2)
                .setMaxTokens(500);
        return client.getChatCompletions(deployment, options).getChoices().get(0).getMessage().getContent();
    }
    ```

!!! info "延伸：Spring AI 與 RAG"

    - **Spring AI** 提供統一的 `ChatClient` 介面，同一套程式可以切換 OpenAI、Azure OpenAI、Anthropic、Ollama 等模型
    - **RAG（Retrieval-Augmented Generation）**：先從自己的資料（商品說明、FAQ）中檢索相關內容，再一起交給模型回答，讓答案有依據、不亂編。檢索通常用向量資料庫（pgvector、OpenSearch k-NN），可以沿用 holidayDessert 已有的 OpenSearch

## Azure AI Vision：圖片描述

``` java
ImageAnalysisResult result = client.analyze(
        BinaryData.fromBytes(file.getBytes()),
        Arrays.asList(VisualFeatures.CAPTION),                     // 要分析的項目
        new ImageAnalysisOptions().setGenderNeutralCaption(true));
String caption = result.getCaption().getText();
```

`VisualFeatures` 還有 `TAGS`（標籤）、`OBJECTS`（物件偵測）、`READ`（雲端 OCR）等選項；同一張圖片可以一次分析多項。也可以用 `analyzeFromUrl` 直接分析網路上的圖片。

## Tesseract OCR

``` java
public OcrService() {
    this.tesseract = new Tesseract();
    this.tesseract.setDatapath("tessdata");        // 語言模型檔所在目錄
}

public ApiReturnObject recognizeText(BufferedImage image) throws TesseractException {
    tesseract.setLanguage("chi_tra");              // 繁體中文；混用可設 "chi_sim+chi_tra"
    String text = tesseract.doOCR(image);
    return ApiReturnObject.success("辨識成功", text);
}
```

| | Tesseract（本機） | 雲端 OCR（Azure Vision READ） |
|---|------------------|------------------------------|
| 費用 | 免費 | 依次數計費 |
| 資料外流 | ✅ 不離開伺服器 | 圖片送到雲端 |
| 準確度 | 依圖片品質，手寫與複雜版面較差 | 較高，支援手寫 |
| 部署 | 需要 `tessdata` 語言檔與原生函式庫 | 只要 API Key |

!!! warning "Tesseract 的部署細節"

    - Docker 映像中要安裝 Tesseract 原生函式庫，並把 `tessdata` 一起打包（holidayDessert 專案根目錄就有 `tessdata/`）
    - `Tesseract` 物件**不是執行緒安全的**，共用同一個實例時要加鎖或改用物件池
    - 辨識前先做灰階、二值化、放大，準確度會明顯提升

## 報表與文件

| 函式庫 | 用途 | 注意 |
|--------|------|------|
| **iTextPDF** | 產生 PDF（訂單、票券） | 中文要嵌入字型；iText 7 以後為 AGPL 授權，商業使用要確認 |
| **Apache POI** | 讀寫 `.xlsx` / `.docx` | 大量資料用 `SXSSFWorkbook` 串流寫入，避免 OOM |
| **JExcelAPI** | 讀寫舊版 `.xls` | 已不維護，新功能建議改用 POI |

## Jasypt：設定檔加密

``` yaml
spring:
  datasource:
    password: ENC(加密後的字串)          # 啟動時由 Jasypt 解密
jasypt:
  encryptor:
    password: ${JASYPT_ENCRYPTOR_PASSWORD}   # 解密金鑰從環境變數讀取，不寫進設定檔
```

Jasypt 讓設定檔可以放進版控而不洩漏密碼。但解密金鑰本身仍要妥善保管；在雲端環境，更好的做法是改用 [AWS Secrets Manager](../../engineering/aws/operations-security.md) 或 Azure Key Vault，由平台管理與輪替。
