----------------------------------------------------------------------------------
-- Engineer: Hosseinali
-- Create Date: 02/09/2024 04:33:33 PM
-- Module Name: GPS_simulator - Behavioral
-- Project Name: PMU
-- Target Devices: ZYNQ7010
-- Description: This design immitates the nmea output of the GPS modules, this is fully synthesizable and all of the calculations are done by ur PC not ur target device.  
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity GPS_simulator is
generic
(
    IP_FREQUENCY    : integer   := 100000000;
    Send_interval   : integer   := 1; -- How many NMEA sentences should be sent per second. 
    First_sentence  : string    := "$GPGGA,161229.487,3723.2475,N,12158.3416,W,1,07,1.0,9.0,M,,,,0000*18";
    Second_sentence : string    := "$GPZDA,172809.45,12,07,1996,00,00*45"
);
    Port (     
            clk         : in STD_LOGIC;
            nRST        : in STD_LOGIC;
            tREADY      : in STD_LOGIC;
            tVALID      : out STD_LOGIC;
            tDATA       : out STD_LOGIC_VECTOR (7 downto 0)
        );
end GPS_simulator;

architecture Behavioral of GPS_simulator is
    subtype slv is std_logic_vector;
-------------------------------------------------------------------------------------
------ This function converts strings to binary with std_logic_vector type ----------
------------------------------------------------------------------------------------- 
function to_slv(s: string) return std_logic_vector is 
    constant ss: string(1 to s'length) := s; 
    variable answer: std_logic_vector(1 to 8 * s'length); 
    variable p: integer; 
    variable c: integer; 
begin 
    for i in ss'range loop
        p := 8 * i;
        c := character'pos(ss(i));
        answer(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
    end loop; 
    return answer;
end function;

----------------------------------------------------------------------------
-- number of first and second sentence characters. ----
constant first_sent_cnt : integer := First_sentence'length;  
constant sec_sent_cnt : integer := Second_sentence'length; 

--- msb and lsb of the first and sec sentences ----- 
constant First_sentence_msb : integer := first_sent_cnt*8-1;
constant second_sentence_msb : integer := sec_sent_cnt*8-1;

------------ sentences in binary ----------------------
constant binary_First_sentence : STD_LOGIC_VECTOR(First_sentence_msb downto 0) := to_slv(First_sentence); 
constant binary_second_sentence : STD_LOGIC_VECTOR(second_sentence_msb downto 0) := to_slv(Second_sentence);

----- send interval calculation which is related to the input freq of the module ---- 
constant Send_delay_clks    : integer := IP_FREQUENCY/Send_interval; 

signal cnt : unsigned(29 downto 0) := (others=>'0'); 
signal character_index : unsigned(7 downto 0) := to_unsigned(1,8);


--- spliting the characters for putting them into array ---- 
type frsplitterType is array(1 to first_sent_cnt) of std_logic_vector(7 downto 0);
signal splt_First_sentence : frsplitterType := (others=>(others=>'0'));
type sesplitterType is array(1 to sec_sent_cnt) of std_logic_vector(7 downto 0);
signal splt_second_sentence : sesplitterType := (others=>(others=>'0'));
-------------------------------------------------------------

--- State machine ---- 
type fsmType is (idle,sending_first,gap,gap_1,sending_sec,interval,waiting); 
signal FSM : fsmType := idle; 

begin

--- putting the characters into array --- 
Fr_assignment:for i in 1 to first_sent_cnt generate 
    splt_First_sentence(i) <= binary_First_sentence(First_sentence_msb-((i-1)*8) downto First_sentence_msb-(i*8-1));
end generate; 
se_assignment:for i in 1 to sec_sent_cnt generate 
    splt_second_sentence(i) <= binary_second_sentence(second_sentence_msb-((i-1)*8) downto second_sentence_msb-(i*8-1));
end generate; 

process(clk)
begin
if(nRST='0') then 

else 
    if rising_edge(clk) then
        tVALID        <= '0';

        --- cnt counter is used for interval cal so it counts when the FSM is not idle ---- 
        if(FSM /= idle) then 
            cnt         <= cnt +1;  
        end if;  
    
        ---- this is the state machine controlling the whole process --- 
        case FSM is 
            when idle => 
                FSM     <= sending_first; 
                if(tREADY = '0') then --- only when the next module is ready the data will be sent
                    FSM     <= idle; 
                end if; 
            when sending_first => 
                tVALID  <= '1'; 
                tDATA   <= splt_First_sentence(to_integer(character_index)); --- charecters in binary format will be sent one by one 
                FSM     <= gap; 
            --- this is the gap between each character of the fisrt sentence ---- 
            when gap => 
                if(tREADY ='1') then
                    FSM             <= sending_first; 
                    character_index <= character_index +1; 
                end if; 
                if(character_index = to_unsigned(first_sent_cnt,8) and tREADY = '1') then
                    FSM             <= sending_sec;
                    character_index <= to_unsigned(1,8);
                end if; 
            when sending_sec => 
                tVALID  <= '1'; 
                tDATA   <= splt_second_sentence(to_integer(character_index));
                FSM     <= gap_1; 
            --- this is the gap between each character of the second sentence ----     
            when gap_1 => 
                if(tREADY ='1') then
                    FSM             <= sending_sec; 
                    character_index <= character_index +1; 
                end if;             
                if(character_index = to_unsigned(sec_sent_cnt,8) and tREADY = '1' ) then
                    FSM             <= interval;
                    character_index <= to_unsigned(1,8);
                end if; 
            --- this state stops the whole process---     
            when interval =>
                if(cnt = to_unsigned(Send_delay_clks-1,30)) then 
                    FSM         <= idle; 
                    cnt         <= (others=>'0');
                end if; 
            when others => 
        end case; 
    end if; 
end if; 
end process; 
end Behavioral;
