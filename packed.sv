
typedef struct packed {
logic status;
	logic [3:0] digit1;
	logic [3:0] digit2;
	logic [3:0] digit3;
	logic [3:0] digit4;
} pinPac_t;

typedef struct packed {
	logic [3:0] BCD0;
	logic [3:0] BCD1;
	logic [3:0] BCD2;
	logic [3:0] BCD3;
	logic [3:0] BCD4;
	logic [3:0] BCD5;
} bcdPac_t;

typedef struct packed {
	logic bip_status;
	logic [6:0] bip_time;
	logic [6:0]  tranca_aut_time;
	pinPac_t master_pin;
	pinPac_t pin1;
	pinPac_t pin2;
	pinPac_t pin3;
	pinPac_t pin4;
} setupPac_t;
