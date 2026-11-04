package com.sk.skala.myapp;

import static org.junit.jupiter.api.Assertions.*;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.sk.skala.myapp.domain.*;
import com.sk.skala.myapp.repository.*;
import com.sk.skala.myapp.service.OrderService;

/** 실제 H2 트랜잭션·HTTP 요청을 사용하며 운영 DB에는 연결하지 않는다. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
    "spring.datasource.url=jdbc:h2:mem:order-tests;DB_CLOSE_DELAY=-1",
    "spring.sql.init.mode=never", "spring.jpa.show-sql=false",
    "management.server.port=0"
})
class OrderWorkflowTests {
    @Autowired OrderService service;
    @Autowired ProductRepository products;
    @Autowired UserRepository users;
    @Autowired OrderRepository orders;
    @Autowired PaymentRepository payments;
    @Autowired DeliveryRepository deliveries;
    @Autowired PlatformTransactionManager transactionManager;
    @LocalServerPort int port;
    Product product;
    User user;

    @BeforeEach
    void setUp() {
        orders.deleteAll();
        deliveries.deleteAll();
        payments.deleteAll();
        products.deleteAll();
        users.deleteAll();
        user = new User();
        user.setName("Test customer");
        user.setEmail("customer@example.com");
        user = users.save(user);
        product = new Product();
        product.setName("Test product");
        product.setPrice(1000);
        product.setStockQuantity(1);
        product.setStatus(ProductStatus.ON_SALE);
        product.setUser(user);
        product = products.save(product);
    }

    @Test
    void orderPersistsPaymentDeliveryAndStockTogether() {
        var order = service.createOrder(product.getId(), user.getId(), 1, "Test address");
        assertNotNull(order.getId());
        assertEquals(0, products.findById(product.getId()).orElseThrow().getStockQuantity());
        assertEquals(1000, payments.findAll().getFirst().getAmount());
        assertEquals(PaymentStatus.PENDING, payments.findAll().getFirst().getStatus());
        assertEquals("Test address", deliveries.findAll().getFirst().getAddress());
        assertEquals(1, orders.count());
    }

    @Test
    void insufficientStockDoesNotLeavePartialRecords() {
        assertThrows(IllegalStateException.class,
                () -> service.createOrder(product.getId(), user.getId(), 2, null));
        assertEquals(1, products.findById(product.getId()).orElseThrow().getStockQuantity());
        assertEquals(0, orders.count());
        assertEquals(0, payments.count());
        assertEquals(0, deliveries.count());
    }

    @Test
    void nonpositiveQuantityIsRejectedAtServiceBoundary() {
        for (int quantity : new int[] { 0, -1 }) {
            assertThrows(IllegalArgumentException.class,
                    () -> service.createOrder(product.getId(), user.getId(), quantity, null));
        }
        assertEquals(1, products.findById(product.getId()).orElseThrow().getStockQuantity());
        assertEquals(0, orders.count());
    }

    @Test
    void amountOverflowRollsBackStockChange() {
        product.setPrice(Integer.MAX_VALUE);
        product.setStockQuantity(2);
        products.save(product);
        assertThrows(IllegalArgumentException.class,
                () -> service.createOrder(product.getId(), user.getId(), 2, null));
        assertEquals(2, products.findById(product.getId()).orElseThrow().getStockQuantity());
        assertEquals(0, orders.count());
    }

    @Test
    void stateTransitionsPersistPaymentAndDeliveryCompletion() {
        long id = service.createOrder(product.getId(), user.getId(), 1, null).getId();
        for (int step = 0; step < 4; step++) service.advanceStatus(id);
        assertEquals(OrderStatus.DELIVERY_COMPLETED, orders.findById(id).orElseThrow().getStatus());
        assertEquals(PaymentStatus.COMPLETED, payments.findAll().getFirst().getStatus());
        assertNotNull(payments.findAll().getFirst().getPaidAt());
        assertEquals(DeliveryStatus.COMPLETED, deliveries.findAll().getFirst().getStatus());
        assertEquals(OrderStatus.DELIVERY_COMPLETED, service.advanceStatus(id).getStatus());
    }

    @Test
    void concurrentOrdersCannotBothConsumeTheLastItem() throws Exception {
        var barrier = new CyclicBarrier(2);
        Callable<Boolean> placeOrder = () -> {
            try {
                new TransactionTemplate(transactionManager).execute(status -> {
                    service.createOrder(product.getId(), user.getId(), 1, null);
                    try {
                        // 양쪽이 같은 버전의 마지막 재고를 읽은 뒤 커밋하도록 고정한다.
                        barrier.await(10, TimeUnit.SECONDS);
                    } catch (Exception exception) {
                        throw new IllegalStateException("Concurrent test did not synchronize", exception);
                    }
                    return null;
                });
                return true;
            } catch (OptimisticLockingFailureException expected) {
                return false;
            }
        };
        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(placeOrder);
            var second = executor.submit(placeOrder);
            int successes = (first.get(20, TimeUnit.SECONDS) ? 1 : 0)
                    + (second.get(20, TimeUnit.SECONDS) ? 1 : 0);
            assertEquals(1, successes);
        }
        assertEquals(0, products.findById(product.getId()).orElseThrow().getStockQuantity());
        assertEquals(1, orders.count());
        assertEquals(1, payments.count());
        assertEquals(1, deliveries.count());
    }

    @Test
    void apiReportsCreatedValidationConflictAndNotFound() throws Exception {
        String body = "{\"productId\":" + product.getId() + ",\"userId\":" + user.getId();
        var invalid = request("POST", "/api/orders", body + ",\"quantity\":0}");
        assertEquals(400, invalid.statusCode());
        assertTrue(invalid.body().contains("quantity"));
        assertEquals(201, request("POST", "/api/orders", body + ",\"quantity\":1}").statusCode());
        assertEquals(409, request("POST", "/api/orders", body + ",\"quantity\":1}").statusCode());
        assertEquals(404, request("GET", "/api/orders/999999", null).statusCode());
    }

    private HttpResponse<String> request(String method, String path, String body) throws Exception {
        var builder = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header("Content-Type", "application/json");
        builder.method(method, body == null ? HttpRequest.BodyPublishers.noBody()
                : HttpRequest.BodyPublishers.ofString(body));
        try (var client = HttpClient.newHttpClient()) {
            return client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
        }
    }
}
