# WebSocket（即時通訊）

!!! abstract "本章重點"

    HTTP 只能由客戶端發起請求，需要伺服器主動推送時就要用 WebSocket。本章說明握手升級的原理，以及在 Spring Boot 中用 STOMP 協定實作訂閱、廣播與點對點訊息。

## WebSocket 原理

**HTTP 請求/響應模式的問題**

- 客戶端必須主動發請求才能獲得數據
- 服務器無法主動推送！

**解決方案的演進**

**輪詢（Polling）**

- 客戶端每秒發一次請求：「有新消息嗎？」
- ❌ 浪費頻寬，延遲高

**長輪詢（Long Polling）**

- 客戶端發請求，服務器掛起直到有數據才返回
- ❌ 連接數多，資源浪費

**WebSocket**

- ✅ 一次握手，建立持久雙向連接
- ✅ 服務器可以主動推送
- ✅ 低延遲，低開銷

**WebSocket 握手過程**

- ① 客戶端發 HTTP 請求（帶特殊頭）
    - GET /ws HTTP/1.1
    - Upgrade: websocket
    - Connection: Upgrade
    - Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ\=\=

- ② 服務器返回 101 Switching Protocols
    - HTTP/1.1 101 Switching Protocols
    - Upgrade: websocket
    - Connection: Upgrade
    - Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=

- ③ 連接建立，雙方可以互相發送數據幀
    - ws://  → 非加密
    - wss:// → 加密（生產環境必須用！）

## Spring Boot 整合（STOMP over WebSocket）

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-websocket</artifactId>
</dependency>
```

=== "WebSocket 配置"

    ``` java
    // WebSocket 配置
    @Configuration
    @EnableWebSocketMessageBroker
    public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

        @Override
        public void configureMessageBroker(MessageBrokerRegistry registry) {
            // 啟用記憶體內消息代理，處理帶有 /topic 和 /queue 前綴的消息
            registry.enableSimpleBroker("/topic", "/queue");

            // 應用程序處理帶有 /app 前綴的消息
            registry.setApplicationDestinationPrefixes("/app");

            // 點對點消息前綴（用戶私信）
            registry.setUserDestinationPrefix("/user");
        }

        @Override
        public void registerStompEndpoints(StompEndpointRegistry registry) {
            registry.addEndpoint("/ws")           // WebSocket 連接端點
                .setAllowedOriginPatterns("*")    // 允許跨域
                .withSockJS();                    // 支援 SockJS 降級（不支援 WS 時用輪詢）
        }

        @Override
        public void configureClientInboundChannel(ChannelRegistration registration) {
            // 加入認證攔截器
            registration.interceptors(new AuthChannelInterceptor());
        }
    }
    ```

=== "WebSocket 認證攔截器"

    ``` java
    // WebSocket 認證攔截器
    @Component
    @RequiredArgsConstructor
    public class AuthChannelInterceptor implements ChannelInterceptor {

        private final JwtTokenProvider jwtTokenProvider;

        @Override
        public Message<?> preSend(Message<?> message, MessageChannel channel) {
            StompHeaderAccessor accessor =
                MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);

            if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                String token = accessor.getFirstNativeHeader("Authorization");
                if (token != null && token.startsWith("Bearer ")) {
                    token = token.substring(7);
                    if (jwtTokenProvider.validateToken(token)) {
                        // 設定用戶身份（用於點對點消息）
                        String username = jwtTokenProvider.getUsername(token);
                        accessor.setUser(() -> username);
                    }
                }
            }
            return message;
        }
    }
    ```


=== "聊天室實戰"

    ``` java
    // 消息 DTO
    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public class ChatMessage {
        public enum MessageType { CHAT, JOIN, LEAVE, SYSTEM }

        private MessageType   type;
        private String        content;
        private String        sender;
        private String        roomId;
        private LocalDateTime timestamp;
    }

    // 聊天室 Controller
    @Controller
    @RequiredArgsConstructor
    @Slf4j
    public class ChatController {

        private final SimpMessagingTemplate messagingTemplate;
        private final ChatRoomService       chatRoomService;

    ```

=== "① 群組消息"

    ``` java
        // 客戶端：stompClient.send("/app/chat/{roomId}", {}, message)
        @MessageMapping("/chat/{roomId}")
        public void sendGroupMessage(@DestinationVariable String roomId,
                                      ChatMessage message,
                                      Principal principal) {
            message.setSender(principal.getName());
            message.setTimestamp(LocalDateTime.now());
            message.setType(ChatMessage.MessageType.CHAT);

            log.info("[{}] {} 發送消息：{}", roomId, message.getSender(), message.getContent());

            // 廣播到聊天室訂閱者
            // 訂閱：stompClient.subscribe('/topic/chat/{roomId}', callback)
            messagingTemplate.convertAndSend(
                "/topic/chat/" + roomId,
                message
            );

            // 保存消息記錄
            chatRoomService.saveMessage(roomId, message);
        }

    ```

=== "② 點對點私信"

    ``` java
        // 客戶端：stompClient.send("/app/private/{recipientId}", {}, message)
        @MessageMapping("/private/{recipientId}")
        public void sendPrivateMessage(@DestinationVariable String recipientId,
                                        ChatMessage message,
                                        Principal principal) {
            message.setSender(principal.getName());
            message.setTimestamp(LocalDateTime.now());
            message.setType(ChatMessage.MessageType.CHAT);

            // 發送給特定用戶
            // 訂閱：stompClient.subscribe('/user/queue/private', callback)
            messagingTemplate.convertAndSendToUser(
                recipientId,
                "/queue/private",
                message
            );

            log.info("{} → {}: {}", message.getSender(), recipientId, message.getContent());
        }

    ```

=== "③ 用戶加入聊天室"

    ``` java
        @MessageMapping("/chat/{roomId}/join")
        public void joinRoom(@DestinationVariable String roomId,
                              Principal principal) {
            String username = principal.getName();
            chatRoomService.addUser(roomId, username);

            ChatMessage notification = new ChatMessage(
                ChatMessage.MessageType.JOIN,
                username + " 加入了聊天室",
                "系統",
                roomId,
                LocalDateTime.now()
            );

            messagingTemplate.convertAndSend("/topic/chat/" + roomId, notification);
        }

    ```

=== "④ 用戶離開"

    ``` java
        @EventListener
        public void handleDisconnect(SessionDisconnectEvent event) {
            StompHeaderAccessor accessor =
                StompHeaderAccessor.wrap(event.getMessage());
            String username = Optional.ofNullable(accessor.getUser())
                .map(Principal::getName)
                .orElse("Unknown");

            String roomId = chatRoomService.getUserRoom(username);
            if (roomId != null) {
                chatRoomService.removeUser(roomId, username);

                ChatMessage notification = new ChatMessage(
                    ChatMessage.MessageType.LEAVE,
                    username + " 離開了聊天室",
                    "系統",
                    roomId,
                    LocalDateTime.now()
                );
                messagingTemplate.convertAndSend("/topic/chat/" + roomId, notification);
            }
        }
    }
    ```

=== "服務器主動推送"

    ``` java
    // 服務器主動推送（如：訂單狀態更新、系統通知）
    @Service
    @RequiredArgsConstructor
    public class NotificationService {

        private final SimpMessagingTemplate messagingTemplate;

        // 推送給特定用戶
        public void pushToUser(String userId, Object notification) {
            messagingTemplate.convertAndSendToUser(
                userId,
                "/queue/notifications",
                notification
            );
        }

        // 廣播給所有連線用戶
        public void broadcast(Object notification) {
            messagingTemplate.convertAndSend(
                "/topic/system",
                notification
            );
        }
    }
    ```


```javascript
// 前端 JavaScript（使用 SockJS + STOMP.js）

const socket = new SockJS('/ws');
const stompClient = Stomp.over(socket);

// 連接（帶 JWT Token）
stompClient.connect(
    { 'Authorization': 'Bearer ' + jwtToken },
    function(frame) {
        console.log('WebSocket 連接成功：' + frame);

        // 訂閱聊天室消息
        stompClient.subscribe('/topic/chat/' + roomId, function(message) {
            const chatMsg = JSON.parse(message.body);
            displayMessage(chatMsg);
        });

        // 訂閱私信
        stompClient.subscribe('/user/queue/private', function(message) {
            const privateMsg = JSON.parse(message.body);
            displayPrivateMessage(privateMsg);
        });

        // 訂閱系統通知
        stompClient.subscribe('/topic/system', function(message) {
            const notification = JSON.parse(message.body);
            showNotification(notification);
        });

        // 加入聊天室
        stompClient.send('/app/chat/' + roomId + '/join', {}, '');
    },
    function(error) {
        console.log('連接失敗：' + error);
        setTimeout(() => reconnect(), 5000);  // 自動重連
    }
);

// 發送消息
function sendMessage(content) {
    stompClient.send('/app/chat/' + roomId, {}, JSON.stringify({
        content: content,
        roomId:  roomId
    }));
}

// 斷開連接
function disconnect() {
    if (stompClient) {
        stompClient.disconnect(() => console.log('已斷開連接'));
    }
}
```

!!! example "我的實作：兩種 WebSocket 實作"

    holidayDessert 的客服聊天室用 **STOMP over WebSocket**，stock-observation 的直播聊天室用 **WebFlux 原生 WebSocket + Reactor Sinks**，兩者的比較整理在即時通訊章節。

    👉 [即時通訊與串流](realtime-streaming.md)
