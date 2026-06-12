import datetime


class Order:
    def __init__(self, id, customer, items, status, total):
        self.id = id
        self.customer = customer
        self.items = items
        self.status = status
        self.total = total


class OrderService:
    def process(self, order, country_code, customer_tier):
        # validate
        if order.status != "new":
            raise Exception("bad status")
        if not order.items:
            raise Exception("empty")

        subtotal = 0
        for it in order.items:
            subtotal += it["price"] * it["qty"]

        # discounts
        if customer_tier == 2:
            subtotal = subtotal * 0.9
        elif customer_tier == 3:
            subtotal = subtotal * 0.85

        # tax
        if country_code == "US":
            tax = subtotal * 0.07
        elif country_code == "DE":
            tax = subtotal * 0.19
        elif country_code == "GB":
            tax = subtotal * 0.20
        else:
            tax = subtotal * 0.15

        # shipping
        if subtotal > 100:
            shipping = 0
        else:
            shipping = 9.99

        total = subtotal + tax + shipping
        order.total = total
        order.status = "processed"

        # audit
        with open("/var/log/orders.log", "a") as f:
            f.write(str(datetime.datetime.now()) + " " + str(order.id) + " " + str(total) + "\n")

        return total
