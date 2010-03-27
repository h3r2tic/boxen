module xf.boxen.Vehicle;

private {
	import xf.game.Defs : playerId, NoPlayer;
	import xf.omg.core.LinearAlgebra;
}



interface IVehicle {
	// Covered by MVehicle
		int			numSeats();
		playerId	getPlayerAtSeat(int seat);
		int			setPlayerAtSeat(playerId, int seat = -1);
		int			getPlayerSeatId(playerId);
		bool		removePlayerFromSeat(playerId);
		playerId	pilotId();
	// ----
	
	
	//SgNode	getSeatSgNode(int seat);
	
	void		onPilotLeave();
	void		move(float x, float y, float z);
	void		yawRotate(float angle);
	void		pitchRotate(float angle);
	void		shoot();
	
	bool		getSafeLeavePosition(vec3*);
}



template MVehicle(int _numSeats) {
	private import tango.stdc.stdio : printf;
	
	
	int numSeats() {
		return _numSeats;
	}
	
	
	playerId getPlayerAtSeat(int seat) {
		return _seats[seat];
	}
	
	
	int getPlayerSeatId(playerId pid) {
		foreach (i, ref s; _seats) {
			if (pid == s) {
				return i;
			}
		}
		
		return -1;
	}
	
	
	bool removePlayerFromSeat(playerId pid) {
		foreach (i, ref s; _seats) {
			if (pid == s) {
				if (0 == i) {
					onPilotLeave();
				}
				
				s = NoPlayer;
				return true;
			}
		}
		return false;
	}
	
		
	/**
		Put player at a seat
		if seat == -1, the first available seat is chosen and returned
		if there were no free seats, -1 is returned
		if the player already was at this seat, -1 is returned
	*/
	int setPlayerAtSeat(playerId pid, int seat = -1) {
		if (-1 == seat) {
			assert (pid != NoPlayer);
			
			foreach (i, ref s; _seats) {
				if (pid == s) {
					printf("setPlayerAtSeat: player is already at the pilot/driver seat"\n);
					return -1;
				}
				
				if (NoPlayer == s) {
					return setPlayerAtSeat(pid, i);
				}
			}
			
			return -1;		// fail
		} else {
			if (seat < 0 || seat >= _numSeats) {
				return -1;
			} else {
				if (NoPlayer == pid) {
					if (0 == seat) {
						onPilotLeave();
					}
					
					_seats[seat] = NoPlayer;
					return seat;
				} else {
					if (NoPlayer == _seats[seat]) {
						removePlayerFromSeat(pid);
						_seats[seat] = pid;
						return seat;
					} else {
						return -1;
					}
				}
			}
		}
	}


	playerId pilotId() {
		return getPlayerAtSeat(0);
	}
	
	
	private {
		playerId[_numSeats]	_seats = NoPlayer;
	}
}
